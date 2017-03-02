/**
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
package com.suse.manager.webui.services.impl.runner;

import com.google.gson.annotations.SerializedName;
import com.google.gson.reflect.TypeToken;
import com.suse.salt.netapi.calls.RunnerCall;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Runner calls specific to SUSE Manager.
 */
public class MgrUtilRunner {

    private MgrUtilRunner() { }

    /**
     * Command execution result.
     */
    public static class ExecResult {

        @SerializedName("returncode")
        private int returnCode;
        @SerializedName("stdout")
        private String stdout;
        @SerializedName("stderr")
        private String stderr;

        /**
         * @return command return code
         */
        public int getReturnCode() {
            return returnCode;
        }

        /**
         * @return command stdout
         */
        public String getStdout() {
            return stdout;
        }

        /**
         * @return command stderr
         */
        public String getStderr() {
            return stderr;
        }
    }

    /**
     * Generate a ssh key pair.
     * @param path path where to generate the keys
     * @return the execution result
     */
    public static RunnerCall<ExecResult> generateSSHKey(String path) {
        Map<String, Object> args = new LinkedHashMap<>();
        args.put("path", path);
        RunnerCall<ExecResult> call =
                new RunnerCall<>("mgrutil.ssh_keygen", Optional.of(args),
                        new TypeToken<ExecResult>() { });
        return call;
    }

    /**
     * Connect through the given hosts to execute the command
     * on the last host in the chain.
     * @param hosts the hosts through which to connect
     * @param clientKey the key to auth on the first host
     * @param proxyKey the key to auth on subsequent hosts
     * @param user the user used to connect
     * @param options SSH options
     * @param command the command to execute
     * @param outputfile the file to which to dump the command stdout
     * @return the execution result
     */
    public static RunnerCall<ExecResult> chainSSHCommand(List<String> hosts,
                                                         String clientKey,
                                                         String proxyKey,
                                                         String user,
                                                         Map<String, String> options,
                                                         String command,
                                                         String outputfile) {
        Map<String, Object> args = new LinkedHashMap<>();
        args.put("hosts", hosts);
        args.put("clientkey", clientKey);
        args.put("proxykey", proxyKey);
        args.put("user", user);
        args.put("options", options);
        args.put("command", command);
        args.put("outputfile", outputfile);
        RunnerCall<ExecResult> call =
                new RunnerCall<>("mgrutil.chain_ssh_cmd", Optional.of(args),
                        new TypeToken<ExecResult>() {
                        });
        return call;
    }

}
