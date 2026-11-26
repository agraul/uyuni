/*
 * Copyright (c) 2019 SUSE LLC
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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import com.redhat.rhn.common.hibernate.HibernateFactory;
import com.redhat.rhn.domain.channel.Channel;
import com.redhat.rhn.domain.channel.ChannelFactoryTest;
import com.redhat.rhn.domain.rhnpackage.Package;
import com.redhat.rhn.domain.rhnpackage.PackageCapability;
import com.redhat.rhn.domain.rhnpackage.PackageExtraTagsKeys;
import com.redhat.rhn.domain.rhnpackage.PackageProvides;
import com.redhat.rhn.manager.rhnpackage.PackageManager;
import com.redhat.rhn.manager.rhnpackage.PackageManagerTest;
import com.redhat.rhn.testing.BaseTestCaseWithUser;
import com.redhat.rhn.testing.TestUtils;

import org.apache.commons.io.FileUtils;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.zip.GZIPInputStream;

public class DebRepositoryWriterTest extends BaseTestCaseWithUser {

    private Path tmpDir;

    @BeforeEach
    public void setUp() throws Exception {
        tmpDir = Files.createTempDirectory("debPkgWriterTest");
    }

    @Test
    public void testWriteRepoMetadata() throws Exception {
        Channel channel = ChannelFactoryTest.createBaseChannel(user);

        PackageExtraTagsKeys multiArchTag = PackageManagerTest.createExtraTagKey("Multi-Arch");

        Package pkg1 = PackageManagerTest.addPackageToChannel("pkg_1", channel);
        pkg1.getExtraTags().add(PackageManagerTest.createExtraTag(multiArchTag, "same", pkg1));
        Package pkg2 = PackageManagerTest.addPackageToChannel("pkg_2", channel);
        Package pkg3 = PackageManagerTest.addPackageToChannel("pkg_3", channel);

        PackageManager.createRepoEntrys(channel.getId());

        TestUtils.flushAndClearSession();

        DebRepositoryWriter writer = new DebRepositoryWriter("rhn/repodata", tmpDir.normalize().toString());
        writer.setCommitTransaction(false);
        writer.writeRepomdFiles(channel);
        Path channelRepodataDir = tmpDir.resolve("rhn/repodata/" + channel.getLabel());
        List<String> fileNames = Files.list(channelRepodataDir)
                .map(path -> path.getFileName().toString())
                .toList();
        assertTrue(fileNames.contains("Release"));
        assertTrue(fileNames.contains("Packages"));
        assertTrue(fileNames.contains("Packages.gz"));

        String packagesContent = FileUtils.readFileToString(
                tmpDir.resolve("rhn/repodata/" + channel.getLabel() + "/Packages").toFile());
        packagesContent = DebPackageWriterTest.cleanupContent(packagesContent);

        try (FileInputStream fin = new FileInputStream(
                tmpDir.resolve("rhn/repodata/" + channel.getLabel() + "/Packages.gz").toFile());
             InputStream gzipStream = new GZIPInputStream(fin)) {

            String packagesGzContent = TestUtils.readAll(gzipStream);
            packagesGzContent = DebPackageWriterTest.cleanupContent(packagesGzContent);

            assertEquals(packagesContent, packagesGzContent);
        }
        catch (IOException e) {
            fail(e.getMessage());
        }
    }

    @Test
    public void testIncompatibleSaltPackagesAreNotWritten() throws Exception {
        HibernateFactory.getSession().createNativeMutationQuery("DELETE FROM suseManagerInfo").executeUpdate();
        HibernateFactory.getSession()
                .createNativeMutationQuery("INSERT INTO suseManagerInfo (salt_protocol_abi) VALUES ('3007.1.0')")
                .executeUpdate();

        Channel channel = ChannelFactoryTest.createBaseChannel(user);
        Package compatible = PackageManagerTest.addPackageToChannel("salt_compatible", channel);
        providesSaltProtocolAbi(compatible, "3007.1.0");
        Package incompatible = PackageManagerTest.addPackageToChannel("salt_incompatible", channel);
        providesSaltProtocolAbi(incompatible, "3008.1.0");
        PackageManagerTest.addPackageToChannel("not_salt", channel);

        PackageManager.createRepoEntrys(channel.getId());
        TestUtils.flushAndClearSession();

        DebRepositoryWriter writer = new DebRepositoryWriter("rhn/repodata", tmpDir.normalize().toString());
        writer.setCommitTransaction(false);
        writer.writeRepomdFiles(channel);

        String packagesContent = FileUtils.readFileToString(
                tmpDir.resolve("rhn/repodata/" + channel.getLabel() + "/Packages").toFile());
        assertTrue(packagesContent.contains("Package: salt_compatible"));
        assertTrue(packagesContent.contains("Package: not_salt"));
        assertFalse(packagesContent.contains("Package: salt_incompatible"));
    }

    private static void providesSaltProtocolAbi(Package pkg, String abi) {
        PackageCapability capability = new PackageCapability();
        capability.setName(SaltProtocolAbi.CAPABILITY_NAME);
        capability.setVersion(abi);
        capability = TestUtils.saveAndReload(capability);

        PackageProvides provides = new PackageProvides();
        provides.setCapability(capability);
        provides.setPack(pkg);
        provides.setSense(8L);
        TestUtils.saveAndFlush(provides);
    }

    @AfterEach
    public void tearDown() throws Exception {
        FileUtils.deleteDirectory(tmpDir.toFile());
    }

}
