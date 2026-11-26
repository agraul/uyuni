/*
 * Copyright (c) 2009--2011 Red Hat, Inc.
 *
 * This software is licensed to you under the GNU General Public License,
 * version 2 (GPLv2). There is NO WARRANTY for this software, express or
 * implied, including the implied warranties of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
 * along with this software; if not, see
 * http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *
 * Red Hat trademarks are not licensed under GPLv2. No permission is
 * granted to use or replicate Red Hat trademarks that are incorporated
 * in this software or its documentation.
 */
package com.redhat.rhn.taskomatic.task.repomd;

import com.redhat.rhn.domain.channel.Channel;
import com.redhat.rhn.domain.common.ManagerInfoFactory;
import com.redhat.rhn.manager.satellite.Executor;
import com.redhat.rhn.manager.task.TaskManager;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.io.File;
import java.util.Collections;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 *
 *
 */
public abstract class RepositoryWriter {

    protected Logger log = LogManager.getLogger(RepositoryWriter.class);
    protected final String pathPrefix;
    protected final String mountPoint;
    protected final Executor cmdExecutor;

    protected boolean commitTransaction = true;

    /**
     * Constructor takes in pathprefix and mountpoint
     * @param pathPrefixIn prefix to package path
     * @param mountPointIn mount point package resides
     * @param cmdExecutorIn {@link Executor} instance to run system commands
     */
    protected RepositoryWriter(String pathPrefixIn, String mountPointIn, Executor cmdExecutorIn) {
        this.pathPrefix = pathPrefixIn;
        this.mountPoint = mountPointIn;
        this.cmdExecutor = cmdExecutorIn;
    }

    /**
     * Whether to commit hibernate transaction or not. Default is commit.
     * Only used in unit tests.
     *
     * @param commitTransactionIn flag to set
     */
    public void setCommitTransaction(boolean commitTransactionIn) {
        this.commitTransaction = commitTransactionIn;
    }

   /**
    *
    * @param channel channel info
    * @return repodata sanity
    */
    public abstract boolean isChannelRepodataStale(Channel channel);

    /**
    *
    * @param channel channelinfo for repomd file creation
    */
   public abstract void writeRepomdFiles(Channel channel);

    /**
     * Find the packages of a channel that must not be part of the metadata because they require a newer
     * Salt protocol ABI than the Salt Master provides. Packages without the capability are compatible.
     * If the ABI of the Salt Master is unknown, all packages are compatible.
     */
    protected Set<Long> findIncompatibleSaltPackageIds(Channel channel) {
        Optional<String> storedAbi = ManagerInfoFactory.getSaltProtocolAbi();
        Optional<SaltProtocolAbi> masterAbi = storedAbi.flatMap(SaltProtocolAbi::parse);
        if (masterAbi.isEmpty()) {
            log.info("Salt Master protocol ABI '{}' is unknown or invalid, not excluding Salt packages",
                    storedAbi.orElse(""));
            return Collections.emptySet();
        }
        Set<Long> excluded = new HashSet<>();
        Map<Long, String> packageAbis = TaskManager.getChannelSaltProtocolAbis(channel);
        log.debug("Salt Master protocol ABI is {}, channel '{}' has {} packages providing {}: {}", masterAbi.get(),
                channel.getLabel(), packageAbis.size(), SaltProtocolAbi.CAPABILITY_NAME, packageAbis);
        packageAbis.forEach((packageId, version) -> {
            Optional<SaltProtocolAbi> packageAbi = SaltProtocolAbi.parse(version);
            if (packageAbi.isPresent() && !packageAbi.get().isCompatibleWith(masterAbi.get())) {
                excluded.add(packageId);
            }
        });
        if (!excluded.isEmpty()) {
            log.info("Excluding {} Salt packages incompatible with protocol ABI {} from channel '{}'",
                    excluded.size(), masterAbi.get(), channel.getLabel());
        }
        return excluded;
    }

   /**
    * Deletes repository cache files
    * @param channelLabelToProcess channel label
    * @param deleteDir directory to delete
    */
   public void deleteRepomdFiles(String channelLabelToProcess, boolean deleteDir) {
       log.info("Removing {}", channelLabelToProcess);
       String prefix = mountPoint + File.separator + pathPrefix + File.separator +
               channelLabelToProcess;
       File theDirectory = new File(prefix);

       String[] children = theDirectory.list();
       if (theDirectory.isDirectory() && children != null) {
           for (String childIn : children) {
               File file = new File(prefix + File.separator + childIn);
               if (!file.delete()) {
                   log.info("Couldn't remove {}", file.getAbsolutePath());
               }
           }
       }
       if (deleteDir) {
           if (!theDirectory.delete()) {
               log.info("Couldn't remove {}", prefix);
           }
       }
   }
}
