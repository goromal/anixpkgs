import argparse, os, string

def process(src, sft, lve):
    a = string.ascii_letters + '.' + string.digits
    ext = '.tyz'

    if not os.path.exists(src):
        print('Specified source does not exist: %s' % src)
        exit()

    for l in src:
        if not l in a:
            print('Letters, numbers, and dots only, please.')
            exit()

    if ext in src:
        print('...and back again.')
        cvt = False
    else:
        print('There...')
        cvt = True

    if not cvt:
        srcp = src.replace(ext,'')
    else:
        srcp = src

    s_a = a[sft:] + a[:sft]
    tbl = (str.maketrans(a, s_a) if cvt else str.maketrans(s_a, a))
    tf = srcp.translate(tbl)
    if cvt:
        tf += ext

    print('%s -> %s' % (src, tf))

    with open(src, 'rb') as inf, open(tf, 'wb') as outf:
        for line in inf:
            line = [c^ord(lve) for c in line]
            outf.write(bytearray(line))

def main():
    parser = argparse.ArgumentParser(description='Make some scrambled eggs.')
    parser.add_argument('target', type=str, action='store', help='File target.')
    parser.add_argument('shift', type=int, action='store', help='Shift amount.')
    parser.add_argument('key', type=str, action='store', help='Scramble key.')
    args = parser.parse_args()
    process(args.target, args.shift, args.key)

if __name__ == '__main__':
    main()