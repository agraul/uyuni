/*
 * Copyright (c) 2017 SUSE LLC
 *
 * This software is licensed to you under the GNU General Public License,
 * version 2 (GPLv2). There is NO WARRANTY for this software, express or
 * implied, including the implied warranties of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
 * along with this software; if not, see
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
 *
 * Red Hat trademarks are not licensed under GPLv2. No permission is
 * granted to use or replicate Red Hat trademarks that are incorporated
 * in this software or its documentation.
 */

package com.suse.manager.webui.controllers;

import static com.suse.manager.webui.utils.SparkApplicationHelper.asJson;
import static com.suse.manager.webui.utils.SparkApplicationHelper.json;
import static com.suse.manager.webui.utils.SparkApplicationHelper.withCsrfToken;
import static com.suse.manager.webui.utils.SparkApplicationHelper.withDocsLocale;
import static com.suse.manager.webui.utils.SparkApplicationHelper.withUser;
import static com.suse.manager.webui.utils.SparkApplicationHelper.withUserAndServer;
import static spark.Spark.get;
import static spark.Spark.post;

import com.redhat.rhn.common.db.datasource.DataResult;
import com.redhat.rhn.common.hibernate.LookupException;
import com.redhat.rhn.domain.action.Action;
import com.redhat.rhn.domain.action.ActionChain;
import com.redhat.rhn.domain.action.ActionChainFactory;
import com.redhat.rhn.domain.channel.Channel;
import com.redhat.rhn.domain.channel.ChannelFactory;
import com.redhat.rhn.domain.credentials.Credentials;
import com.redhat.rhn.domain.rhnpackage.PackageEvr;
import com.redhat.rhn.domain.rhnset.RhnSet;
import com.redhat.rhn.domain.role.RoleFactory;
import com.redhat.rhn.domain.server.MgrServerInfo;
import com.redhat.rhn.domain.server.MinionServer;
import com.redhat.rhn.domain.server.Server;
import com.redhat.rhn.domain.server.ServerFactory;
import com.redhat.rhn.domain.server.ServerGroupFactory;
import com.redhat.rhn.domain.user.User;
import com.redhat.rhn.frontend.context.Context;
import com.redhat.rhn.frontend.dto.EssentialChannelDto;
import com.redhat.rhn.frontend.dto.SystemOverview;
import com.redhat.rhn.frontend.dto.VirtualSystemOverview;
import com.redhat.rhn.frontend.struts.StrutsDelegate;
import com.redhat.rhn.manager.action.ActionChainManager;
import com.redhat.rhn.manager.channel.ChannelManager;
import com.redhat.rhn.manager.entitlement.EntitlementManager;
import com.redhat.rhn.manager.rhnset.RhnSetDecl;
import com.redhat.rhn.manager.rhnset.RhnSetManager;
import com.redhat.rhn.manager.system.SystemManager;
import com.redhat.rhn.taskomatic.TaskomaticApiException;

import com.suse.manager.reactor.utils.LocalDateTimeISOAdapter;
import com.suse.manager.reactor.utils.OptionalTypeAdapterFactory;
import com.suse.manager.webui.services.iface.SaltApi;
import com.suse.manager.webui.utils.FlashScopeHelper;
import com.suse.manager.webui.utils.PageControlHelper;
import com.suse.manager.webui.utils.gson.ChannelsJson;
import com.suse.manager.webui.utils.gson.PagedDataResultJson;
import com.suse.manager.webui.utils.gson.ResultJson;
import com.suse.manager.webui.utils.gson.SubscribeChannelsJson;
import com.suse.manager.webui.utils.gson.VirtualSystem;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import org.apache.commons.lang3.StringEscapeUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.http.HttpStatus;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.apache.struts.action.ActionErrors;
import org.apache.struts.action.ActionMessage;
import org.apache.struts.action.ActionMessages;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Collections;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import javax.servlet.http.HttpServletRequest;

import spark.ModelAndView;
import spark.Request;
import spark.Response;
import spark.template.jade.JadeTemplateEngine;

/**
 * Controller class providing backend code for the systems page.
 */
public class SystemsController {

    private final SaltApi saltApi;

    /**
     * @param saltApiIn instance for getting information from a system.
     */
    public SystemsController(SaltApi saltApiIn) {
        this.saltApi = saltApiIn;
    }

    // Logger for this class
    private static final Logger LOG = LogManager.getLogger(SystemsController.class);

    private static final Gson GSON = new GsonBuilder()
            .registerTypeAdapter(LocalDateTime.class, new LocalDateTimeISOAdapter())
            .registerTypeAdapterFactory(new OptionalTypeAdapterFactory())
            .serializeNulls()
            .create();

    /**
     * Invoked from Router. Initialize routes for Systems Views.
     *
     * @param jade Jade template engine
     */
    public void initRoutes(JadeTemplateEngine jade) {
        get("/manager/systems/list/virtual",
                withCsrfToken(withDocsLocale(withUser(this::virtualListPage))), jade);
        get("/manager/systems/details/mgr-server-info/:sid",
                withCsrfToken(withDocsLocale(withUserAndServer(this::mgrServerInfoPage))),
                jade);
        post("/manager/api/systems/:sid/mgr-server-reportdb-newpw", withUser(this::mgrServerNewReportDbPassword));
        post("/manager/api/systems/:sid/delete", withUser(this::delete));
        get("/manager/api/systems/:sid/channels", withUser(this::getChannels));
        get("/manager/api/systems/:sid/channels-available-base",
                withUser(this::getAvailableBaseChannels));
        post("/manager/api/systems/:sid/channels", withUser(this::subscribeChannels));
        get("/manager/api/systems/:sid/channels/:channelId/accessible-children",
                withUser(this::getAccessibleChannelChildren));
        get("/manager/api/systems/list/virtual", asJson(withUser(this::virtualSystems)));
    }

    private Object virtualSystems(Request request, Response response, User user) {
        PageControlHelper pageHelper = new PageControlHelper(request, "hostServerName");

        DataResult<VirtualSystemOverview> virtual = SystemManager.virtualSystemsList(user, null);
        if ("id".equals(pageHelper.getFunction())) {
            return json(response, virtual.stream()
                    .filter(SystemOverview::isSelectable)
                    .map(VirtualSystemOverview::getUuid)
                    .collect(Collectors.toList())
            );
        }

        virtual = pageHelper.processPageControl(virtual, new HashMap<>());
        List<VirtualSystem> systems = virtual.stream()
                .map(system -> {
                    system.setSystemId(system.getVirtualSystemId());
                    if (system.getSystemId() != null) {
                        system.updateStatusType(user);
                    }
                    return new VirtualSystem(system);
                })
                .collect(Collectors.toList());
        return json(response, new PagedDataResultJson<>(systems, virtual.getTotalSize()));
    }

    /**
     * Get the virtual systems list page
     *
     * @param requestIn the request
     * @param responseIn the response
     * @param userIn the user
     * @return the jade rendered template
     */
    private ModelAndView virtualListPage(Request requestIn, Response responseIn, User userIn) {
        Map<String, Object> data = new HashMap<>();
        data.put("is_admin", userIn.hasRole(RoleFactory.ORG_ADMIN));
        return new ModelAndView(data, "templates/systems/virtual-list.jade");
    }

    /**
     * Get the virtual systems list page
     *
     * @param request the request
     * @param response the response
     * @param user the user
     * @param server the server
     * @return the jade rendered template
     */
     public ModelAndView mgrServerInfoPage(Request request, Response response, User user, Server server) {
        MgrServerInfo info = server.getMgrServerInfo();
        Map<String, Object> data = new HashMap<>();

        data.put("is_admin", user.hasRole(RoleFactory.ORG_ADMIN));
        data.put("name", server.getName());
        data.put("version", Optional.ofNullable(info.getVersion())
                .map(PackageEvr::toUniversalEvrString)
                .orElse(""));
        data.put("reportDbName", info.getReportDbName());
        data.put("reportDbHost", info.getReportDbHost());
        data.put("reportDbPort", info.getReportDbPort());
        data.put("reportDbUser", Optional.ofNullable(info.getReportDbCredentials())
                .map(Credentials::getUsername)
                .orElse(""));
        data.put("reportDbLastSynced", info.getReportDbLastSynced());

        return new ModelAndView(data, "templates/systems/mgr-server.jade");
     }

     /**
      * Autogenerate a new password for a Mgr Servers report database,
      * set it in the DB and schedule a password change on that server.
      *
      * @param request the request
      * @param response the response
      * @param user the user
      * @return the json response
      */
     public String mgrServerNewReportDbPassword(Request request, Response response, User user) {
         String sidStr = request.params("sid");
         long sid;
         try {
             sid = Long.parseLong(sidStr);
         }
         catch (NumberFormatException e) {
             LOG.error(String.format("SystemID (%s) not a long", sidStr));
             return json(response, HttpStatus.SC_BAD_REQUEST, ResultJson.error("invalid_systemid"));
         }
         Server server = null;
         try {
             server = SystemManager.lookupByIdAndUser(sid, user);
         }
         catch (Exception e) {
             LOG.error(e.getMessage());
             return json(response, HttpStatus.SC_BAD_REQUEST, ResultJson.error("unknown_system"));
         }
         if (server.isMgrServer()) {
             Optional<MinionServer> minion = server.asMinionServer();
             if (minion.isEmpty()) {
                 LOG.error(String.format("System (%s) not a minion", sidStr));
                 return json(response, HttpStatus.SC_BAD_REQUEST, ResultJson.error("system_not_mgr_server"));
             }
             SystemManager.setReportDbUser(minion.get(), true);
         }
         else {
             LOG.error(String.format("System (%s) not a Mgr Server", sidStr));
             return json(response, HttpStatus.SC_BAD_REQUEST, ResultJson.error("system_not_mgr_server"));
         }
         return json(response, ResultJson.success());
     }

    /**
     * Deletes a system.
     * @param request the request
     * @param response the response
     * @param user the user
     * @return the json response
     */
    public String delete(Request request, Response response, User user) {
        String sidStr = request.params("sid");
        Boolean noclean = Boolean.parseBoolean(GSON.fromJson(request.body(), Map.class).get("nocleanup").toString());
        long sid;
        try {
            sid = Long.parseLong(sidStr);
        }
        catch (NumberFormatException e) {
            return json(response, HttpStatus.SC_BAD_REQUEST, ResultJson.success());
        }
        Server server = SystemManager.lookupByIdAndUser(sid, user);
        boolean isEmptyProfile = server.hasEntitlement(EntitlementManager.BOOTSTRAP);

        if (server.asMinionServer().isPresent()) {
            if (!noclean && !isEmptyProfile) {
                Optional<List<String>> cleanupErr =
                        saltApi.cleanupMinion(server.asMinionServer().get(), 300);
                if (cleanupErr.isPresent()) {
                    return json(response, ResultJson.error(cleanupErr.get()));
                }
            }
        }

        if (server.hasEntitlement(EntitlementManager.MANAGEMENT)) {
            // But what if this system is in some other user's RhnSet???
            RhnSet set = RhnSetDecl.SYSTEMS.get(user);

            // Remove from SSM if required
            if (set.getElementValues().contains(sid)) {
                set.removeElement(sid);
                RhnSetManager.store(set);
            }
        }

        try {
            // Now we can remove the system
            SystemManager systemManager = new SystemManager(ServerFactory.SINGLETON, ServerGroupFactory.SINGLETON,
                    saltApi);
            systemManager.deleteServer(user, sid);
            createSuccessMessage(request.raw(), "message.serverdeleted.param",
                    Long.toString(sid));
        }
        catch (RuntimeException e) {
            if (e.getMessage().contains("cobbler")) {
                createErrorMessage(request.raw(), "message.servernotdeleted_cobbler",
                        Long.toString(sid));
            }
            else {
                createErrorMessage(request.raw(),
                        "message.servernotdeleted", Long.toString(sid));
                throw e;
            }
        }
        FlashScopeHelper.flash(request, "Deleted successfully");
        return json(response, ResultJson.success());
    }

    /**
     * Get the current channels of a system.
     *
     * @param request the http request
     * @param response the http response
     * @param user the user
     * @return the json response
     */
    public String getChannels(Request request, Response response, User user) {
        return withServer(request, response, user, (server) -> {
            Channel base = server.getBaseChannel();
            ChannelsJson jsonChannels = new ChannelsJson();
            if (base != null) {
                jsonChannels.setBase(base);
                jsonChannels.setChildren(server.getChildChannels().stream());
            }

            return json(response, ResultJson.success(jsonChannels));
        });
    }

    /**
     * Get base channels available for a system.
     *
     * @param request the http request
     * @param response the http response
     * @param user the user
     * @return the json response
     */
    public String getAvailableBaseChannels(Request request, Response response, User user) {
        return withServer(request, response, user, (server) -> {
            List<EssentialChannelDto> orgChannels = ChannelManager.listBaseChannelsForSystem(
                    user, server);
            List<ChannelsJson.ChannelJson> baseChannels =
                    orgChannels.stream().map(c -> new ChannelsJson.ChannelJson(c.getId(),
                            c.getLabel(),
                            c.getName(),
                            c.isCustom(),
                            true,
                            c.isCloned(),
                            c.getArchLabel()
                            ))
                    .collect(Collectors.toList());

            return json(response, ResultJson.success(baseChannels));
        });
    }

    private String withServer(Request request, Response response, User user, Function<Server, String> handler) {
        long serverId;
        try {
            serverId = Long.parseLong(request.params("sid"));
        }
        catch (NumberFormatException e) {
            return json(response,
                    HttpStatus.SC_BAD_REQUEST,
                    ResultJson.error("invalid_server_id"));
        }
        Server server = ServerFactory.lookupById(serverId);
        if (server == null) {
            return json(response,
                    HttpStatus.SC_NOT_FOUND,
                    ResultJson.error("server_not_found"));
        }
        return handler.apply(server);
    }

    /**
     * Subscribe a system to channels.
     * @param request the http request
     * @param response the http response
     * @param user the user
     * @return the json response
     */
    public String subscribeChannels(Request request, Response response, User user) {
        long serverId;
        try {
            serverId = Long.parseLong(request.params("sid"));
        }
        catch (NumberFormatException e) {
            return json(response,
                    HttpStatus.SC_BAD_REQUEST,
                    ResultJson.error("invalid_server_id"));
        }
        SubscribeChannelsJson json = GSON.fromJson(request.body(), SubscribeChannelsJson.class);
        Optional<Channel> base = Optional.empty();
        Set<Channel> children;
        if (json.getBase().filter(b -> b.getId() > -1).isPresent()) {
            // we have a base selected and its id is not -1
            base = Optional.ofNullable(ChannelFactory
                    .lookupByIdAndUser(json.getBase().get().getId(), user));
            if (!base.isPresent()) {
                return json(response,
                        HttpStatus.SC_FORBIDDEN,
                        ResultJson.error("base_not_found_or_not_authorized"));
            }
        }
        try {
            children = Optional.ofNullable(json.getChildren())
                    .map(l -> l
                            .stream()
                            .map(m ->
                                    Optional.ofNullable(
                                            ChannelFactory.lookupByIdAndUser(m.getId(), user))
                                        .orElseThrow(() -> new IllegalArgumentException(m.getName()))
                            )
                            .collect(Collectors.toSet()))
                    .orElse(Collections.emptySet());
        }
        catch (IllegalArgumentException e) {
            return json(response,
                    HttpStatus.SC_FORBIDDEN,
                    ResultJson.error("child_not_found_or_not_authorized", e.getMessage()));
        }

        ActionChain actionChain = json.getActionChain()
                .filter(StringUtils::isNotEmpty)
                .map(label -> ActionChainFactory.getOrCreateActionChain(label, user))
                .orElse(null);

        ZoneId zoneId = Context.getCurrentContext().getTimezone().toZoneId();
        Date earliest = Date.from(
                json.getEarliest().orElseGet(LocalDateTime::now).atZone(zoneId).toInstant()
        );

        try {
            Set<Action> sca = ActionChainManager.scheduleSubscribeChannelsAction(user,
                    Collections.singleton(serverId),
                    base,
                    children,
                    earliest,
                    actionChain);
            return json(response, ResultJson.success(
                    actionChain != null ? actionChain.getId() :
                    sca.stream().findFirst().map(Action::getId).orElse(null)));
        }
        catch (TaskomaticApiException e) {
            return json(response, HttpStatus.SC_INTERNAL_SERVER_ERROR,
                    ResultJson.error("taskomatic_error"));
        }
    }

    protected void createSuccessMessage(HttpServletRequest req, String msgKey,
                                        String param1) {
        ActionMessages msg = new ActionMessages();
        Object[] args = new Object[1];
        args[0] = StringEscapeUtils.escapeHtml4(param1);
        msg.add(ActionMessages.GLOBAL_MESSAGE, new ActionMessage(msgKey, args));
        StrutsDelegate.getInstance().saveMessages(req, msg);
    }

    protected void createErrorMessage(HttpServletRequest req, String beanKey,
                                      String param) {
        ActionErrors errs = new ActionErrors();
        String escParam = StringEscapeUtils.escapeHtml4(param);
        errs.add(ActionMessages.GLOBAL_MESSAGE, new ActionMessage(beanKey, escParam));
        StrutsDelegate.getInstance().saveMessages(req, errs);
    }

    /**
     * Get available child channels for a base channel.
     * @param request the request
     * @param response the response
     * @param user the user
     * @return the json response
     */
    public Object getAccessibleChannelChildren(Request request, Response response, User user) {
        return withServer(request, response, user, (server) -> {
            long channelId;
            try {
                channelId = Long.parseLong(request.params("channelId"));
            }
            catch (NumberFormatException e) {
                return json(response,
                        HttpStatus.SC_BAD_REQUEST,
                        ResultJson.error("invalid_channel_id"));
            }

            Channel oldBaseChannel =  null;
            try {
                String paramOldBaseChannelId = request.queryParams("oldBaseChannelId");
                if (paramOldBaseChannelId != null) {
                    Long oldBaseChannelId = Long.parseLong(paramOldBaseChannelId);
                    oldBaseChannel = ChannelManager.lookupByIdAndUser(oldBaseChannelId, user);
                }
            }
            catch (Exception e) {
                // This is not a critical feature for this request, we want to keep moving forward anyway
                // but log that something unexpected happened
                LOG.error("A wrong oldBaseChannelId parameter was provided when fetching childchannels", e);
            }

            try {
                if (channelId < 0) {
                    // disable base channel
                    return json(response, Collections.emptyList());
                }

                Channel baseChannel = ChannelManager.lookupByIdAndUser(channelId, user);
                if (!baseChannel.isBaseChannel()) {
                    return json(response,
                            HttpStatus.SC_BAD_REQUEST,
                            ResultJson.error("not_a_base_channel"));
                }

                Map<Channel, Channel> preservationsByOldChild =
                        ChannelManager.findCompatibleChildren(oldBaseChannel, baseChannel, user);

                // invert preservations
                Map<Channel, Channel> preservationsByNewChild = new HashMap<>();
                for (Channel previousChannel : preservationsByOldChild.keySet()) {
                    Channel newChannel = preservationsByOldChild.get(previousChannel);
                    if (!preservationsByNewChild.containsKey(newChannel)) {
                        preservationsByNewChild.put(newChannel, previousChannel);
                    }
                }

                List<Channel> children = baseChannel.getAccessibleChildrenFor(user);

                Map<Long, Boolean> channelRecommendedFlags = ChannelManager.computeChannelRecommendedFlags(
                        baseChannel,
                        children.stream().filter(c -> c.isSubscribable(user.getOrg(), server)));

                List<ChannelsJson.ChannelJson> jsonList = children.stream()
                        .filter(c -> c.isSubscribable(user.getOrg(), server))
                        .map(c -> new ChannelsJson.ChannelJson(c.getId(),
                                c.getLabel(),
                                c.getName(),
                                c.isCustom(),
                                c.isSubscribable(user.getOrg(), server),
                                c.isCloned(),
                                c.getChannelArch().getLabel(),
                                channelRecommendedFlags.get(c.getId()),
                                preservationsByNewChild.get(c) != null ? preservationsByNewChild.get(c).getId() : null))
                        .collect(Collectors.toList());
                return json(response, ResultJson.success(jsonList));
            }
            catch (LookupException e) {
                return json(response,
                        HttpStatus.SC_NOT_FOUND,
                        ResultJson.error("invalid_channel_id"));
            }
        });
    }
}
