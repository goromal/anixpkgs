#!/usr/bin/python3

import sys
import re
import os
import time
import signal
import argparse
import subprocess
import configparser
import socket
import urllib.request as request
import urllib.parse as parse
import urllib.error
import builtins
import json
import gzip
import pyperclip
import base64
import csv
from os.path import expanduser, expandvars
import os.path
from datetime import datetime
from io import BytesIO
import shutil
import colorama
import veryprettytable as pretty

DATABLACKLIST = [
        "https://thebay.tv",
        "https://piratebaymirror.eu",
        "http://proxyspotting.in",
        "https://proxyspotting.in",
        "https://knaben.xyz/ThePirateBay.php"
    ]

DATACATEGORIES = {
"All": 0,
"Applications": 300,
"Applications/Android": 306,
"Applications/Handheld": 304,
"Applications/IOS (iPad/iPhone)": 305,
"Applications/Mac": 302,
"Applications/Other OS": 399,
"Applications/UNIX": 303,
"Applications/Windows": 301,
"Audio": 100,
"Audio/Audio books": 102,
"Audio/FLAC": 104,
"Audio/Music": 101,
"Audio/Other": 199,
"Audio/Sound clips": 103,
"Games": 400,
"Games/Android": 408,
"Games/Handheld": 406,
"Games/IOS (iPad/iPhone)": 407,
"Games/Mac": 402,
"Games/Other": 499,
"Games/PC": 401,
"Games/PSx": 403,
"Games/Wii": 405,
"Games/XBOX360": 404,
"Other": 600,
"Other/Comics": 602,
"Other/Covers": 604,
"Other/E-books": 601,
"Other/Other": 699,
"Other/Physibles": 605,
"Other/Pictures": 603,
"Video": 200,
"Video/3D": 209,
"Video/HD - Movies": 207,
"Video/HD - TV shows": 208,
"Video/Handheld": 206,
"Video/Movie clips": 204,
"Video/Movies": 201,
"Video/Movies DVDR": 202,
"Video/Music videos": 203,
"Video/Other": 299,
"Video/TV shows": 205
}

DATASORTS = {
"TitleDsc": [1, "name", True],
"TitleAsc": [2, "name", False],
"DateDsc":  [3, "raw_uploaded", True],
"DateAsc":  [4, "raw_uploaded", False],
"SizeDsc":  [5, "raw_size", True],
"SizeAsc":  [6, "raw_size", False],
"SeedersDsc": [7, "seeders", True],
"SeedersAsc": [8, "seeders", False],
"LeechersDsc": [9, "leechers", True],
"LeechersAsc": [10, "leechers", False],
"CategoryDsc": [13, "category", True],
"CategoryAsc": [14, "category", False],
"Default": [99, "seeders", True]
}

def parse_category(printer, category):
    try:
        category = int(category)
    except ValueError:
        pass
    if category in DATACATEGORIES.values():
        return category
    elif category in DATACATEGORIES.keys():
        return DATACATEGORIES[category]
    else:
        printer.print('Invalid category ignored', color='WARN')
        return 0


def parse_sort(printer, sort):
    try:
        sort = int(sort)
    except ValueError:
        pass
    for key, val in DATASORTS.items():
        if sort == key or sort == val[0]:
            return val[1:]
    else:
        printer.print('Invalid sort ignored', color='WARN')
        return DATASORTS['Default'][1:]


def parse_page(page):
    results = []
    try:
        data = json.load(page)
    except json.decoder.JSONDecodeError:
        raise IOError('invalid JSON in API reply: blocked mirror?')

    if len(data) == 1 and 'No results' in data[0]['name']:
        return results

    for res in data:
        res['raw_size'] = int(res['size'])
        res['size'] = pretty_size(int(res['size']))
        res['magnet'] = build_magnet(res['name'], res['info_hash'])
        res['info_hash'] = int(res['info_hash'], 16)
        res['raw_uploaded'] = int(res['added'])
        res['uploaded'] = pretty_date(res['added'])
        res['seeders'] = int(res['seeders'])
        res['leechers'] = int(res['leechers'])
        res['category'] = int(res['category'])
        results.append(res)

    return results


def sort_results(sort, res):
    key, reverse = sort
    return sorted(res, key=lambda x: x[key], reverse=reverse)


def pretty_size(size):
    ranges = [('PiB', 1125899906842624),
              ('TiB', 1099511627776),
              ('GiB', 1073741824),
              ('MiB', 1048576),
              ('KiB', 1024)]
    for unit, value in ranges:
        if size >= value:
            return '{:.1f} {}'.format(size/value, unit)
    return str(size) + ' B'


def pretty_date(ts):
    date = datetime.fromtimestamp(int(ts))
    return date.strftime('%Y-%m-%d %H:%M')


def build_magnet(name, info_hash):
    return 'magnet:?xt=urn:btih:{}&dn={}'.format(
        info_hash, parse.quote(name, ''))


def build_request_path(mode, page, category, terms):
    if mode == 'search':
        query = '/q.php?q={}&cat={}'.format(' '.join(terms), category)
    elif mode == 'top':
        cat = 'all' if category == 0 else category
        query = '/precompiled/data_top100_{}.json'.format(cat)
    elif mode == 'recent':
        query = '/precompiled/data_top100_recent_{}.json'.format(page)
    elif mode == 'browse':
        if category == 0:
            raise Exception('You must specify a category')
        query = '/q.php?q=category:{}'.format(category)
    else:
        raise Exception('Invalid mode', mode)

    return parse.quote(query, '?=&/')


def remote(printer, pages, category, sort, mode, terms, mirror, timeout):
    results = []
    for i in range(1, pages + 1):
        query = build_request_path(mode, i, category, terms)

        # Catch the Ctrl-C exception and exit cleanly
        try:
            req = request.Request(
                mirror + query,
                headers={'User-Agent': 'pirate get'})
            try:
                f = request.urlopen(req, timeout=timeout)
            except urllib.error.URLError as e:
                raise e

            if f.info().get('Content-Encoding') == 'gzip':
                f = gzip.GzipFile(fileobj=BytesIO(f.read()))
        except KeyboardInterrupt:
            printer.print('\nCancelled.')
            sys.exit(0)

        results.extend(parse_page(f))

    return sort_results(sort, results)


def find_api(mirror, timeout):
    # try common paths
    for path in ['', '/apip', '/api.php?url=']:
        req = request.Request(mirror + path + '/q.php?q=test&cat=0',
                              headers={'User-Agent': 'pirate get'})
        try:
            f = request.urlopen(req, timeout=timeout)
            if f.info().get_content_type() == 'application/json':
                return mirror + path
        except urllib.error.HTTPError as e:
            res = e.fp.read().decode()
            if e.code == 503 and 'cf-browser-verification' in res:
                raise IOError('Cloudflare protected')

    # extract api path from main.js
    req = request.Request(mirror + '/static/main.js',
                          headers={'User-Agent': 'pirate get'})
    try:
        f = request.urlopen(req, timeout=timeout)
        if f.info().get_content_type() == 'application/javascript':
            match = re.search("var server='([^']+)'", f.read().decode())
            return mirror + match.group(1)
    except urllib.error.URLError:
        raise IOError('API not found: no main.js')

    raise IOError('API not found')


def get_torrent(info_hash, timeout):
    url = 'http://itorrents.org/torrent/{:X}.torrent'
    req = request.Request(url.format(info_hash),
                          headers={'User-Agent': 'pirate get'})
    req.add_header('Accept-encoding', 'gzip')

    torrent = request.urlopen(req, timeout=timeout)
    if torrent.info().get('Content-Encoding') == 'gzip':
        torrent = gzip.GzipFile(fileobj=BytesIO(torrent.read()))

    return torrent.read()


def save_torrents(printer, chosen_links, results, folder, timeout):
    for link in chosen_links:
        result = results[link]
        torrent_name = result['name'].replace('/', '_').replace('\\', '_')
        file = os.path.join(folder, torrent_name + '.torrent')

        try:
            torrent = get_torrent(result['info_hash'], timeout)
        except urllib.error.HTTPError as e:
            printer.print('There is no cached file for this torrent :('
                          ' \nCode: {} - {}'.format(e.code, e.reason),
                          color='ERROR')
        else:
            open(file, 'wb').write(torrent)
            printer.print('Saved {:X} in {}'.format(result['info_hash'], file))


def save_magnets(printer, chosen_links, results, folder):
    for link in chosen_links:
        result = results[link]
        torrent_name = result['name'].replace('/', '_').replace('\\', '_')
        file = os.path.join(folder,  torrent_name + '.magnet')

        printer.print('Saved {:X} in {}'.format(result['info_hash'], file))
        with open(file, 'w') as f:
            f.write(result['magnet'] + '\n')


def copy_magnets(printer, chosen_links, results):
    clipboard_text = ''
    for link in chosen_links:
        result = results[link]
        clipboard_text += result['magnet'] + "\n"
        printer.print('Copying {:X} to clipboard'.format(result['info_hash']))

    pyperclip.copy(clipboard_text)


# this is used to remove null bytes from the input stream because
# apparently they exist
def replace_iter(iterable):
    for value in iterable:
        yield value.replace("\0", "")

# https://stackoverflow.com/questions/1094841/reusable-library-to-get-human-readable-version-of-file-size#1094933
def sizeof_fmt(num, suffix='B'):
    for unit in ['','Ki','Mi','Gi','Ti','Pi','Ei','Zi']:
        if abs(num) < 1024.0:
            return "%3.1f %s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f %s%s" % (num, 'Yi', suffix)

def search(db, terms):
    with open(db, 'r') as f:
        results = []
        reader = csv.reader(replace_iter(f), delimiter=';')
        for row in reader:
            # skip comments
            if row[0][0] == '#':
                continue
            # 0 is date in rfc 3339 format
            # 1 magnet link hash
            # 2 is title
            # 3 is size in bytes
            if ' '.join(terms).lower() in row[2].lower():
                result = {
                    'date': row[0],
                    'size': sizeof_fmt(int(row[3])),
                    'magnet':
                        'magnet:?xt=urn:btih:' +
                        base64.b16encode(base64.b64decode(row[1])).decode('utf-8') +
                        '&dn=' +
                        parse.quote(row[2]),
                    }
                results.append(result)
        # limit page size to not print walls of results
        # TODO: consider pagination
        results = results[:30]
        return results

def parse_config_file(text):
    config = configparser.RawConfigParser()

    # default options
    config.add_section('Save')
    config.set('Save', 'magnets', 'false')
    config.set('Save', 'torrents', 'false')
    config.set('Save', 'directory', os.getcwd())

    config.add_section('LocalDB')
    config.set('LocalDB', 'enabled', 'false')
    config.set('LocalDB', 'path', expanduser('~/downloads/pirate-get/db'))

    config.add_section('Search')
    config.set('Search', 'total-results', 50)

    config.add_section('Misc')
    # TODO: try to use configparser.BasicInterpolation
    #       for interpolating in the command
    config.set('Misc', 'openCommand', '')
    config.set('Misc', 'transmission', 'false')
    config.set('Misc', 'transmission-auth', '')
    config.set('Misc', 'transmission-endpoint', '')
    config.set('Misc', 'transmission-port', '')  # for backward compatibility
    config.set('Misc', 'colors', 'true')
    config.set('Misc', 'mirror', 'https://apibay.org')
    config.set('Misc', 'timeout', 10)

    config.read_string(text)

    # expand env variables
    directory = expanduser(expandvars(config.get('Save', 'Directory')))
    path = expanduser(expandvars(config.get('LocalDB', 'path')))

    config.set('Save', 'Directory', directory)
    config.set('LocalDB', 'path', path)

    return config


def load_config():
    # user-defined config files
    config_home = os.getenv('XDG_CONFIG_HOME', '~/.config')
    config = expanduser(os.path.join(config_home, 'pirate-get'))

    # read config file
    if os.path.isfile(config):
        with open(config) as f:
            return parse_config_file(f.read())

    return parse_config_file("")


def parse_cmd(cmd, url):
    cmd_args_regex = r'''(('[^']*'|"[^"]*"|(\\\s|[^\s])+)+ *)'''
    ret = re.findall(cmd_args_regex, cmd)
    ret = [i[0].strip().replace('%s', url) for i in ret]
    ret_no_quotes = []
    for item in ret:
        if ((item[0] == "'" and item[-1] == "'") or
           (item[0] == '"' and item[-1] == '"')):
            ret_no_quotes.append(item[1:-1])
        else:
            ret_no_quotes.append(item)
    return ret_no_quotes


def parse_torrent_command(l):
    # Very permissive handling
    # Check for any occurances of c, d, f, p, t, m, or q
    cmd_code_match = re.search(r'([hdfpmtqc])', l,
                               flags=re.IGNORECASE)
    if cmd_code_match:
        code = cmd_code_match.group(0).lower()
    else:
        code = None

    # Clean up command codes
    # Substitute multiple consecutive spaces/commas for single
    # comma remove anything that isn't an integer or comma.
    # Turn into list
    l = re.sub(r'^[hdfp, ]*|[hdfp, ]*$', '', l)
    l = re.sub('[ ,]+', ',', l)
    l = re.sub('[^0-9,-]', '', l)
    parsed_input = l.split(',')

    # expand ranges
    choices = []
    # loop will generate a list of lists
    for elem in parsed_input:
        left, sep, right = elem.partition('-')
        if right:
            choices.append(list(range(int(left), int(right) + 1)))
        elif left != '':
            choices.append([int(left)])

    # flatten list
    choices = sum(choices, [])
    # the current code stores the choices as strings
    # instead of ints. not sure if necessary
    choices = [elem for elem in choices]
    return code, choices

class Printer:
    def __init__(self, enable_color):
        self.enable_color = enable_color

    def print(self, *args, **kwargs):
        if kwargs.get('color', False) and self.enable_color:
            colorama.init()
            color_dict = {
                'default': '',
                'header':  colorama.Back.BLACK + colorama.Fore.WHITE,
                'alt':     colorama.Fore.YELLOW,
                'zebra_0': '',
                'zebra_1': colorama.Fore.BLUE,
                'WARN':    colorama.Fore.MAGENTA,
                'ERROR':   colorama.Fore.RED}

            c = color_dict[kwargs.pop('color')]
            args = (c + args[0],) + args[1:] + (colorama.Style.RESET_ALL,)
            kwargs.pop('color', None)
            return builtins.print(*args, file=sys.stderr, **kwargs)
        else:
            kwargs.pop('color', None)
            return builtins.print(*args, file=sys.stderr, **kwargs)

    # TODO: extract the name from the search results
    #       instead of from the magnet link when possible
    def search_results(self, results, local=None):
        columns = shutil.get_terminal_size((80, 20)).columns
        even = True

        if local:
            table = pretty.VeryPrettyTable(['LINK', 'DATE', 'SIZE', 'NAME'])

            table.align['SIZE'] = 'r'
            table.align['NAME'] = 'l'
        else:
            table = pretty.VeryPrettyTable(['LINK', 'SEED', 'SIZE', 'UPLOAD', 'NAME'])
            table.align['NAME'] = 'l'
            table.align['SEED'] = 'r'
            table.align['SIZE'] = 'r'
            table.align['UPLOAD'] = 'l'

        table.max_width = columns
        table.border = False
        table.padding_width = 1

        result_num = 0

        for n, result in enumerate(results):
            torrent_name = result['name']

            no_seeders = int(result['seeders'])
            no_leechers = int(result['leechers'])
            size = result['size']
            date = result['uploaded']
            content = [n, no_seeders, size, date, torrent_name[:columns - 50]]

            if no_seeders > 0 and result_num < 10:
                result_num += 1
                if even or not self.enable_color:
                    table.add_row(content)
                else:
                    table.add_row(content, fore_color='blue')

            # Alternate between colors
            even = not even
        self.print(table)

    def descriptions(self, chosen_links, results, site, timeout):
        for link in chosen_links:
            result = results[link]
            req = request.Request(
                site + '/t.php?id=' + str(result['id']),
                headers={'User-Agent': 'pirate get'})
            req.add_header('Accept-encoding', 'gzip')
            f = request.urlopen(req, timeout=timeout)

            if f.info().get('Content-Encoding') == 'gzip':
                f = gzip.GzipFile(fileobj=BytesIO(f.read()))

            res = json.load(f)

            # Replace HTML links with markdown style versions
            desc = re.sub(r'<a href="\s*([^"]+?)\s*"[^>]*>(\s*)([^<]+?)(\s*'
                          r')</a>', r'\2[\3](\1)\4', res['descr'])

            self.print('Description for "{}":'.format(result['name']),
                       color='zebra_1')
            self.print(desc, color='zebra_0')

    def file_lists(self, chosen_links, results, site, timeout):
        # the API may returns object instead of list
        def get(obj):
            try:
                return obj[0]
            except KeyError:
                return obj['0']

        for link in chosen_links:
            result = results[link]
            req = request.Request(
                site + '/f.php?id=' + str(result['id']),
                headers={'User-Agent': 'pirate get'})
            req.add_header('Accept-encoding', 'gzip')
            f = request.urlopen(req, timeout=timeout)

            if f.info().get('Content-Encoding') == 'gzip':
                f = gzip.GzipFile(fileobj=BytesIO(f.read()))

            res = json.load(f)

            if len(res) == 1 and 'not found' in get(res[0]['name']):
                self.print('File list not available.')
                return

            self.print('Files in {}:'.format(result['name']), color='zebra_1')
            cur_color = 'zebra_0'

            for f in res:
                name = get(f['name'])
                size = pretty_size(int(get(f['size'])))
                self.print('{:>11} {}'.format(
                    size, name),
                    color=cur_color)
                cur_color = 'zebra_0' if cur_color == 'zebra_1' else 'zebra_1'


def parse_args(args_in):
    parser = argparse.ArgumentParser(
        description='finds and downloads torrents from the Pirate Bay')
    parser.add_argument('-b', '--browse',
                        action='store_true',
                        help='display in Browse mode')
    parser.add_argument('search',
                        nargs='*', help='term to search for')
    parser.add_argument('-c', '--category',
                        help='specify a category to search', default='All')
    parser.add_argument('-s', '--sort',
                        help='specify a sort option', default='SeedersDsc')
    parser.add_argument('-R', '--recent',
                        action='store_true',
                        help='torrents uploaded in the last 48hours. '
                             '*ignored in searches*')
    parser.add_argument('-l', '--list-categories',
                        action='store_true',
                        help='list categories')
    parser.add_argument('--list-sorts', '--list_sorts',
                        action='store_true',
                        help='list types by which results can be sorted')
    parser.add_argument('-p', '--pages',
                        default=1, type=int,
                        help='the number of pages to fetch. '
                             '(only used with --recent)')
    parser.add_argument('-r', '--total-results',
                        type=int,
                        help='maximum number of results to show')
    parser.add_argument('-L', '--local', dest='database',
                        help='a csv file containing the Pirate Bay database '
                             'downloaded from '
                             'https://thepiratebay.org/static/dump/csv/')
    parser.add_argument('-0', dest='first',
                        action='store_true',
                        help='choose the top result')
    parser.add_argument('-a', '--download-all',
                        action='store_true',
                        help='download all results')
    parser.add_argument('-t', '--transmission',
                        action='store_true',
                        help='open magnets with transmission-remote')
    parser.add_argument('-E', '--transmission-endpoint', '--port',
                        metavar='HOSTNAME:PORT', dest='endpoint',
                        help='transmission-remote RPC endpoint. '
                             'default is localhost:9091')
    parser.add_argument('-A', '--transmission-auth', '--auth',
                        metavar='USER:PASSWORD', dest='auth',
                        help='transmission-remote RPC authentication')
    parser.add_argument('-C', '--custom', dest='command',
                        help='open magnets with a custom command'
                              ' (%%s will be replaced with the url)')
    parser.add_argument('-M', '--save-magnets',
                        action='store_true',
                        help='save magnets links as files')
    parser.add_argument('-T', '--save-torrents',
                        action='store_true',
                        help='save torrent files')
    parser.add_argument('-S', '--save-directory',
                        type=str, metavar='DIRECTORY',
                        help='directory where to save downloaded files'
                             ' (if none is given $PWD will be used)')
    parser.add_argument('--disable-colors', dest='disable_color',
                        action='store_true',
                        help='disable colored output')
    parser.add_argument('-m', '--mirror',
                        type=str, nargs='+',
                        help='the pirate bay mirror(s) to use')
    parser.add_argument('-z', '--timeout', type=int,
                        help='timeout in seconds for http requests')
    parser.add_argument('-v', '--version',
                        action='store_true',
                        help='print pirate-get version number')
    parser.add_argument('-j', '--json',
                        action='store_true',
                        help='print results in JSON format to stdout')
    args = parser.parse_args(args_in)

    return args


def combine_configs(config, args):
    # figure out the action - browse, search, top, etc.
    if args.browse:
        args.action = 'browse'
    elif args.recent:
        args.action = 'recent'
    elif args.list_categories:
        args.action = 'list_categories'
    elif args.list_sorts:
        args.action = 'list_sorts'
    elif len(args.search) == 0:
        args.action = 'top'
    else:
        args.action = 'search'

    args.source = 'tpb'
    if args.database or config.getboolean('LocalDB', 'enabled'):
        args.source = 'local_tpb'

    if not args.database:
        args.database = config.get('LocalDB', 'path')

    if args.disable_color or not config.getboolean('Misc', 'colors'):
        args.color = False
    else:
        args.color = True

    if not args.save_directory:
        args.save_directory = config.get('Save', 'directory')

    if not args.mirror:
        args.mirror = config.get('Misc', 'mirror').split()

    if not args.timeout:
        args.timeout = int(config.get('Misc', 'timeout'))

    config_total_results = int(config.get('Search', 'total-results'))
    if not args.total_results and config_total_results:
        args.total_results = config_total_results

    args.transmission_command = ['transmission-remote']
    if args.endpoint:
        args.transmission_command.append(args.endpoint)
    elif config.get('Misc', 'transmission-endpoint'):
        args.transmission_command.append(
            config.get('Misc', 'transmission-endpoint'))
    # for backward compatibility
    elif config.get('Misc', 'transmission-port'):
        args.transmission_command.append(
            config.get('Misc', 'transmission-port'))
    if args.auth:
        args.transmission_command.append('--auth')
        args.transmission_command.append(args.auth)
    elif config.get('Misc', 'transmission-auth'):
        args.transmission_command.append('--auth')
        args.transmission_command.append(
            config.get('Misc', 'transmission-auth'))

    args.output = 'browser_open'
    if args.transmission or config.getboolean('Misc', 'transmission'):
        args.output = 'transmission'
    elif args.save_magnets or config.getboolean('Save', 'magnets'):
        args.output = 'save_magnet_files'
    elif args.save_torrents or config.getboolean('Save', 'torrents'):
        args.output = 'save_torrent_files'
    elif args.command or config.get('Misc', 'openCommand'):
        args.output = 'open_command'

    args.open_command = args.command
    if not args.open_command:
        args.open_command = config.get('Misc', 'openCommand')

    return args

def connect_mirror(mirror, printer, args):
    try:
        printer.print('Trying', mirror, end='... ')
        url = find_api(mirror, args.timeout)
        results = remote(
            printer=printer,
            pages=args.pages,
            category=parse_category(printer, args.category),
            sort=parse_sort(printer, args.sort),
            mode=args.action,
            terms=args.search,
            mirror=url,
            timeout=args.timeout)
    except (urllib.error.URLError, socket.timeout, IOError, ValueError) as e:
        printer.print('Failed', color='WARN', end=' ')
        printer.print('(', e, ')', sep='')
        return None
    else:
        printer.print('Ok', color='alt')
        return results, mirror


def search_mirrors(printer, args):
    # try default or user mirrors
    for mirror in args.mirror:
        result = connect_mirror(mirror, printer, args)
        if result is not None:
            return result

    # download mirror list
    try:
        req = request.Request('https://proxybay.bz/list.txt',
                              headers={'User-Agent': 'pirate get'})
        f = request.urlopen(req, timeout=args.timeout)
    except urllib.error.URLError as e:
        raise IOError('Could not fetch mirrors', e.reason)

    if f.getcode() != 200:
        raise IOError('The proxy bay responded with an error',
                      f.read().decode('utf-8'))

    mirrors = [i.decode('utf-8').strip() for i in f.readlines()][3:]

    # try mirrors
    for mirror in mirrors:
        if mirror in DATABLACKLIST:
            continue
        result = connect_mirror(mirror, printer, args)
        if result is not None:
            return result
    else:
        raise IOError('No more available mirrors')


def pirate_main(args):
    printer = Printer(args.color)

    # browse mode needs a specific category
    if args.browse:
        if args.category == 'All' or args.category == 0:
            printer.print('You must select a specific category in browse mode.'
                          ' ("All" is not valid)', color='ERROR')
            sys.exit(1)

    # print version
    if args.version:
        printer.print('pirate-get, version {}'.format('0.4.0'))
        sys.exit(0)

    # check it transmission is running
    if args.transmission:
        printer.print('Opening Transmission...')
        ret = subprocess.call(args.transmission_command + ['-l'],
                              stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL)
        if ret != 0:
            printer.print('Transmission is not running.')
            sys.exit(1)

    # non-torrent fetching actions

    if args.action == 'list_categories':
        cur_color = 'zebra_0'
        for key, value in sorted(DATACATEGORIES.items()):
            cur_color = 'zebra_0' if cur_color == 'zebra_1' else 'zebra_1'
            printer.print(str(value), '\t', key, sep='', color=cur_color)
        return

    if args.action == 'list_sorts':
        cur_color = 'zebra_0'
        for key, value in sorted(DATASORTS.items()):
            cur_color = 'zebra_0' if cur_color == 'zebra_1' else 'zebra_1'
            printer.print(str(value[0]), '\t', key, sep='', color=cur_color)
        return

    # fetch torrents

    if args.source == 'local_tpb':
        if os.path.isfile(args.database):
            results = search(args.database, args.search)
        else:
            printer.print("Local pirate bay database doesn't exist.",
                          '(%s)' % args.database, color='ERROR')
            sys.exit(1)
    elif args.source == 'tpb':
        try:
            results, site = search_mirrors(printer, args)
        except IOError as e:
            printer.print(e.args[0] + ' :( ', color='ERROR')
            if len(e.args) > 1:
                printer.print(e.args[1])
            sys.exit(1)

    if len(results) == 0:
        printer.print('No results')
        return

    if args.json:
        print(json.dumps(results))
        return
    else:
        # Results are sorted on the request, so it's safe to remove results here.
        if args.total_results:
            results = results[0:args.total_results]
        printer.search_results(results, local=args.source == 'local_tpb')

    # number of results to pick
    if args.first:
        printer.print('Choosing first result')
        choices = [0]
    elif args.download_all:
        printer.print('Downloading all results')
        choices = range(len(results))
    else:
        # interactive loop for per-torrent actions
        while True:
            printer.print("\nSelect links (Type 'h' for more options"
                          ", 'q' to quit)", end='\b', color='alt')
            try:
                cmd = builtins.input(': ')
            except (KeyboardInterrupt, EOFError):
                printer.print('\nCancelled.')
                return

            try:
                code, choices = parse_torrent_command(cmd)
                # Act on option, if supplied
                printer.print('')
                if code == 'h':
                    printer.print('Options:',
                                  '<links>: Download selected torrents',
                                  '[m<links>]: Save magnets as files',
                                  '[c<links>]: Copy magnets to clipboard',
                                  '[t<links>]: Save .torrent files',
                                  '[d<links>]: Get descriptions',
                                  '[f<links>]: Get files',
                                  '[p] Print search results',
                                  '[q] Quit', sep='\n')
                elif code == 'q':
                    printer.print('Bye.', color='alt')
                    return
                elif code == 'd':
                    printer.descriptions(choices, results, site, args.timeout)
                elif code == 'f':
                    printer.file_lists(choices, results, site, args.timeout)
                elif code == 'p':
                    printer.search_results(results)
                elif code == 'm':
                    save_magnets(printer, choices, results,
                                                args.save_directory)
                elif code == 'c':
                    copy_magnets(printer, choices, results)
                elif code == 't':
                    save_torrents(printer, choices, results,
                                                 args.save_directory,
                                                 args.timeout)
                elif not cmd:
                    printer.print('No links entered!', color='WARN')
                else:
                    break
            except Exception as e:
                printer.print('Exception:', e, color='ERROR')
                return

    # output

    if args.output == 'save_magnet_files':
        printer.print('Saving selected magnets...')
        save_magnets(printer, choices,
                                    results, args.save_directory)
        return

    if args.output == 'save_torrent_files':
        printer.print('Saving selected torrents...')
        save_torrents(printer, choices,
                                     results, args.save_directory,
                                     args.timeout)
        return

    for choice in choices:
        url = results[choice]['magnet']
        printer.print('Initializing deluge...')
        deluged_proc = subprocess.Popen(['deluged','-d'])
        time.sleep(3.0)

        printer.print('Adding selected magnet...')
        subprocess.call(['deluge-console','add','-p','\"%s\"' % os.getcwd(),url])

        subprocess.call(['deluge-console'])
        printer.print('Removing deluge-console processes...')
        subprocess.call('for id in `deluge-console info | grep "^ID: " | sed -En "s/ID: //p"`; do deluge-console "rm $id"; done',shell=True)
        printer.print('Shutting down deluge...')
        deluged_proc.send_signal(signal.SIGINT)
        deluged_proc.wait()

def main():
    args = combine_configs(load_config(), parse_args(sys.argv[1:]))
    pirate_main(args)

if __name__ == '__main__':
    main()