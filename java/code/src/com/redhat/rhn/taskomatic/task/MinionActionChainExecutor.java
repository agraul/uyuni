/*
 * Copyright (c) 2018 SUSE LLC
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
package com.redhat.rhn.taskomatic.task;

import com.redhat.rhn.GlobalInstanceHolder;
import com.redhat.rhn.common.hibernate.HibernateFactory;
import com.redhat.rhn.common.localization.LocalizationService;
import com.redhat.rhn.domain.action.ActionChain;
import com.redhat.rhn.domain.action.ActionChainEntry;
import com.redhat.rhn.domain.action.ActionChainFactory;
import com.redhat.rhn.domain.action.ActionFactory;

import com.suse.manager.webui.services.SaltServerActionService;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.quartz.JobExecutionContext;

import java.time.Duration;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * Execute SUSE Manager actions via Salt.
 */
public class MinionActionChainExecutor extends RhnJavaJob {

    public static final int ACTION_DATABASE_GRACE_TIME = 10000;
    public static final long MAXIMUM_TIMEDELTA_FOR_SCHEDULED_ACTIONS = 24; // hours
    public static final LocalizationService LOCALIZATION = LocalizationService.getInstance();

    private final SaltServerActionService saltServerActionService;

    /**
     * Default constructor.
     */
    public MinionActionChainExecutor() {
        this(GlobalInstanceHolder.SALT_SERVER_ACTION_SERVICE);
    }

    /**
     * Constructs an instance specifying the {@link SaltServerActionService}. Meant to be used only for unit test.
     * @param saltServerActionServiceIn the salt service
     */
    public MinionActionChainExecutor(SaltServerActionService saltServerActionServiceIn) {
        saltServerActionService = saltServerActionServiceIn;
    }

    @Override
    public String getConfigNamespace() {
        return "minion_actionchain_executor";
    }

    /**
     * @param context the job execution context
     * @see org.quartz.Job#execute(JobExecutionContext)
     */
    @Override
    public void execute(JobExecutionContext context) {
        if (log.isDebugEnabled()) {
            log.debug("Start minion action chain executor");
        }

        // Measure time to calculate the total duration
        long start = System.currentTimeMillis();
        long actionChainId = Long.parseLong((String)context.getJobDetail()
                .getJobDataMap().get("actionchain_id"));

        ActionChain actionChain = ActionChainFactory
                .getActionChain(actionChainId)
                .orElse(null);

        if (actionChain == null) {
            log.error("Action chain not found id={}", actionChainId);
            return;
        }

        long serverActionsCount = countServerActions(actionChain);
        if (serverActionsCount == 0) {
            log.warn("Waiting " + ACTION_DATABASE_GRACE_TIME + "ms for the Tomcat transaction to complete.");
            // give a second chance, just in case this was scheduled immediately
            // and the scheduling transaction did not have the time to commit
            try {
                Thread.sleep(ACTION_DATABASE_GRACE_TIME);
            }
            catch (InterruptedException e) {
                // never happens
                Thread.currentThread().interrupt();
            }
            HibernateFactory.getSession().clear();
        }

        // calculate offset between scheduled time of
        // actions and (now)
        long timeDelta = Duration
                .between(ZonedDateTime.ofInstant(actionChain.getEarliestAction().toInstant(),
                        ZoneId.systemDefault()), ZonedDateTime.now())
                .toHours();
        if (timeDelta >= MAXIMUM_TIMEDELTA_FOR_SCHEDULED_ACTIONS) {
            log.warn("Scheduled action chain {} was scheduled to be executed more than {} hours ago. Skipping it.",
                    actionChain.getId(), MAXIMUM_TIMEDELTA_FOR_SCHEDULED_ACTIONS);

            List<Long> actionsId = actionChain.getEntries()
                                              .stream()
                                              .map(ActionChainEntry::getActionId)
                                              .filter(Objects::nonNull)
                                              .collect(Collectors.toList());

            ActionFactory.rejectScheduledActions(actionsId,
                LOCALIZATION.getMessage("task.action.rejection.reason", MAXIMUM_TIMEDELTA_FOR_SCHEDULED_ACTIONS));

            return;
        }

        log.info("Executing action chain: {}", actionChainId);

        saltServerActionService.executeActionChain(actionChainId);

        if (log.isDebugEnabled()) {
            long duration = System.currentTimeMillis() - start;
            log.debug("Total duration was: {} ms", duration);
        }
    }

    private long countServerActions(ActionChain actionChain) {
        return actionChain.getEntries()
                          .stream()
                          .map(ActionChainEntry::getAction)
                          .mapToLong(action -> action.getServerActions().size())
                          .sum();
    }
}
