/*
 * Copyright (c) 2022 SUSE LLC
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
package com.suse.manager.ssl;

import com.redhat.rhn.common.RhnRuntimeException;

/**
 * Exception indicating an error during SSL certificate generation
 */
public class SSLCertGenerationException extends RhnRuntimeException {

    /**
     * Create a new SSL certificate generation exception
     *
     * @param message error message
     * @param t the exception causing the error
     */
    public SSLCertGenerationException(String message, Throwable t) {
        super(message, t);
    }

    /**
     * Create a new SSL certificate generation exception
     *
     * @param t the exception causing the error
     */
    public SSLCertGenerationException(Throwable t) {
        super(t);
    }
}
