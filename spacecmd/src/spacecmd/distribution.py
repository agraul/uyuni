#
# Licensed under the GNU General Public License Version 3
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Copyright 2013 Aron Parsons <aronparsons@gmail.com>
#

# NOTE: the 'self' variable is an instance of SpacewalkShell

# wildcard import
# pylint: disable=W0401,W0614

# unused argument
# pylint: disable=W0613

# invalid function name
# pylint: disable=C0103

import gettext
from spacecmd.i18n import _N
from spacecmd.utils import *

translation = gettext.translation('spacecmd', fallback=True)
try:
    _ = translation.ugettext
except AttributeError:
    _ = translation.gettext

def help_distribution_create(self):
    print(_('distribution_create: Create a Kickstart tree'))
    print(_('''usage: distribution_create [options]

options:
  -n NAME
  -p path to tree
  -b base channel to associate with
  -t install type [fedora18|rhel_6/7/8|sles12generic|sles15generic|suse|generic_rpm|...]'''))


def do_distribution_create(self, args, update=False):
    arg_parser = get_argument_parser()
    arg_parser.add_argument('-n', '--name')
    arg_parser.add_argument('-p', '--path')
    arg_parser.add_argument('-b', '--base-channel')
    arg_parser.add_argument('-t', '--install-type')

    (args, options) = parse_command_arguments(args, arg_parser)

    # fill in the name of the distribution when updating
    if update:
        if args:
            options.name = args[0]
        elif not options.name:
            logging.error(_N('The name of the distribution is required'))
            return 1

    if is_interactive(options):
        if not update:
            options.name = prompt_user(_('Name:'), noblank=True)

        options.path = prompt_user(_('Path to Kickstart Tree:'), noblank=True)

        options.base_channel = ''
        while options.base_channel == '':
            print('')
            print(_('Base Channels'))
            print('-------------')
            print('\n'.join(sorted(self.list_base_channels())))
            print('')

            options.base_channel = prompt_user(_('Base Channel:'))

        if options.base_channel not in self.list_base_channels():
            logging.warning(_N('Invalid channel label'))
            options.base_channel = ''

        install_types = \
            self.client.kickstart.tree.listInstallTypes(self.session)

        install_types = [t.get('label') for t in install_types]

        options.install_type = ''
        while options.install_type == '':
            print('')
            print(_('Install Types'))
            print('-------------')
            print('\n'.join(sorted(install_types)))
            print('')

            options.install_type = prompt_user(_('Install Type:'))

            if options.install_type not in install_types:
                logging.warning(_N('Invalid install type'))
                options.install_type = ''
    else:
        if not options.name:
            logging.error(_N('A name is required'))
            return 1

        if not options.path:
            logging.error(_N('A path is required'))
            return 1

        if not options.base_channel:
            logging.error(_N('A base channel is required'))
            return 1

        if not options.install_type:
            logging.error(_N('An install type is required'))
            return 1

    if update:
        self.client.kickstart.tree.update(self.session,
                                          options.name,
                                          options.path,
                                          options.base_channel,
                                          options.install_type)
    else:
        self.client.kickstart.tree.create(self.session,
                                          options.name,
                                          options.path,
                                          options.base_channel,
                                          options.install_type)

    return 0

####################


def help_distribution_list(self):
    print(_('distribution_list: List the available autoinstall trees'))
    print(_('usage: distribution_list'))

def do_distribution_list(self, args, doreturn=False):
    channels = self.client.kickstart.listAutoinstallableChannels(self.session)

    avail_trees = []
    for c in channels:
        trees = self.client.kickstart.tree.list(self.session,
                                                c.get('label'))
        for t in trees:
            label = t.get('label')
            if label not in avail_trees:
                avail_trees.append(label)

    if doreturn:
        return avail_trees
    if avail_trees:
        print('\n'.join(sorted(avail_trees)))

    return None

####################


def help_distribution_delete(self):
    print(_('distribution_delete: Delete a Kickstart tree'))
    print(_('usage: distribution_delete LABEL'))


def complete_distribution_delete(self, text, line, beg, end):
    if len(line.split(' ')) <= 2:
        return tab_completer(self.do_distribution_list('', True),
                             text)

    return None


def do_distribution_delete(self, args):
    arg_parser = get_argument_parser()

    (args, _options) = parse_command_arguments(args, arg_parser)

    if not args:
        self.help_distribution_delete()
        return 1

    # allow globbing of distribution names
    dists = filter_results(self.do_distribution_list('', True), args)
    logging.debug("distribution_delete called with args %s, dists=%s" %
                  (args, dists))

    if not dists:
        logging.error(_N("No distributions matched argument %s") % args)
        return 1

    # Print the distributions prior to the confirmation
    print('\n'.join(sorted(dists)))

    if self.user_confirm(_('Delete distribution tree(s) [y/N]:')):
        for d in dists:
            self.client.kickstart.tree.delete(self.session, d)

    return 0

####################


def help_distribution_details(self):
    print(_('distribution_details: Show the details of a Kickstart tree'))
    print(_('usage: distribution_details LABEL'))


def complete_distribution_details(self, text, line, beg, end):
    return tab_completer(self.do_distribution_list('', True), text)


def do_distribution_details(self, args):
    arg_parser = get_argument_parser()

    (args, _options) = parse_command_arguments(args, arg_parser)

    if not args:
        self.help_distribution_details()
        return 1

    # allow globbing of distribution names
    dists = filter_results(self.do_distribution_list('', True), args)
    logging.debug("distribution_details called with args %s, dists=%s" %
                  (args, dists))

    if not dists:
        logging.error(_N("No distributions matched argument %s") % args)
        return 1

    add_separator = False

    for label in dists:
        details = self.client.kickstart.tree.getDetails(self.session, label)

        channel = \
            self.client.channel.software.getDetails(self.session,
                                                    details.get('channel_id'))

        if add_separator:
            print(self.SEPARATOR)
        add_separator = True

        print(_('Name:    %s') % details.get('label'))
        print(_('Path:    %s') % details.get('abs_path'))
        print(_('Channel: %s') % channel.get('label'))

    return 0

####################


def help_distribution_rename(self):
    print(_('distribution_rename: Rename a Kickstart tree'))
    print(_('usage: distribution_rename OLDNAME NEWNAME'))


def complete_distribution_rename(self, text, line, beg, end):
    if len(line.split(' ')) <= 2:
        return tab_completer(self.do_distribution_list('', True),
                             text)

    return None


def do_distribution_rename(self, args):
    arg_parser = get_argument_parser()

    (args, _options) = parse_command_arguments(args, arg_parser)

    if len(args) != 2:
        self.help_distribution_rename()
        return 1

    oldname = args[0]
    newname = args[1]

    self.client.kickstart.tree.rename(self.session, oldname, newname)

    return 0

####################


def help_distribution_update(self):
    print(_('distribution_update: Update the path of a Kickstart tree'))
    print(_('''usage: distribution_update NAME [options]

options:
  -p path to tree
  -b base channel to associate with
  -t install type [fedora18|rhel_6/7/8|sles12generic|sles15generic|suse|generic_rpm|...]'''))


def complete_distribution_update(self, text, line, beg, end):
    if len(line.split(' ')) <= 2:
        return tab_completer(self.do_distribution_list('', True),
                             text)

    return None


def do_distribution_update(self, args):
    arguments, _ = parse_command_arguments(args, get_argument_parser())
    if not arguments:
        self.help_distribution_update()
    else:
        return self.do_distribution_create(args, update=True)

    return None
