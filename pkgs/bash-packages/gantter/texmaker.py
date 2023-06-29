import sys, os, re, subprocess
import numpy as np
from scipy.optimize import linprog

class SpecParser(object):
    def __init__(self, blanksvg, pdfconv, figdir = "figs"):
        # self.color_specs = {1: 'red', 2: 'blue', 3: 'green', 4: 'yellow', 5: 'cyan', 
        #                     6: 'orange', 7: 'purple', 8: 'gray', 9: 'black', 10: 'white'}
        self.default_color_specs = {1: (255,0,0), 2: (0,0,255), 3: (0,255,0), 4: (255,242,0),
                                    5: (0,173,239), 6: (255,128,0), 7: (191,0,64),
                                    8: (128,128,128), 9: (0,0,0), 10: (255,255,255)}
        self.parent_names = list()
        self.bars = list()
        self.links = list()
        self.figs = list()
        self.colors = list()
        self.max_parent_id = 0
        self.max_time_idx = 0
        self.blanksvg = blanksvg
        self.figdir = figdir
        self.pdfconv = pdfconv

    def colorFunc(self, idx):
        n = (idx % 9) + 1
        return self.default_color_specs[n]

    def colorName(self, idx):
        return 'color%d' % idx

    def getColors(self):
        return self.colors

    def colorHex(self, decval):
        hexval = hex(decval).split('x')[-1].lower()
        if len(hexval) == 1:
            return '0' + hexval
        else:
            return hexval

    def fullColorHex(self, decvals):
        return '%s%s%s' % (self.colorHex(decvals[0]), 
                           self.colorHex(decvals[1]), 
                           self.colorHex(decvals[2]))

    def fixedRange(self, n):
        return [i + 1 for i in range(n)]

    def parseLine(self, line):
        parent_id = None
        child_id = None
        text = None
        time_length = None
        dependency_pids = list()
        dependency_cids = list()
        colorvals = None

        p_c_re = re.findall(r"[0-9]+.[0-9]+>>", line)
        p_re = re.findall(r"[0-9]+>>", line)

        if len(p_c_re) > 0:
            p_c_re_str = p_c_re[0]
            line = line.replace(p_c_re_str, '')
            p_c_re_str = p_c_re_str.replace('>>','')
            parent_id = int(p_c_re_str.split('.')[0])
            child_id = int(p_c_re_str.split('.')[1])
            # if child_id > 1: NEED TO EXPLICITLY SPECIFY DEPENDENCE NOW
            #     dependency_pids.append(parent_id)
            #     dependency_cids.append(child_id - 1)
        elif len(p_re) > 0:
            p_re_str = p_re[0]
            line = line.replace(p_re_str, '')
            c_re = re.findall(r"{{[0-9]+,[0-9]+,[0-9]+}}", line)
            if len(c_re) > 0:
                c_re_str = c_re[0]
                colorvals_str = c_re_str.replace('{{','').replace('}}','').split(',')
                colorvals = [int(cv) for cv in colorvals_str]
                line = line.replace(c_re_str, '')
            p_re_str = p_re_str.replace('>>','')
            parent_id = int(p_re_str)
        else:
            return (None, None, None, None, [], [], None)

        time_length_re = re.findall(r"\(\([0-9]+\)\)", line)
        if len(time_length_re) > 0:
            time_length_re_str = time_length_re[0]
            line = line.replace(time_length_re_str, '')
            time_length_re_str = time_length_re_str.replace('((','').replace('))','')
            time_length = float(time_length_re_str) - 1
        else:
            time_length = 0

        ext_dep_re = re.findall(r"\[\[[0-9]+.[0-9]+\]\]", line)
        if len(ext_dep_re) > 0:
            for ext_dep_re_str in ext_dep_re:
                line = line.replace(ext_dep_re_str, '')
                ext_dep_re_str = ext_dep_re_str.replace('[[','').replace(']]','')
                dependency_pids.append(int(ext_dep_re_str.split('.')[0]))
                dependency_cids.append(int(ext_dep_re_str.split('.')[1]))

        text = line.strip()

        return (parent_id, child_id, text, time_length, dependency_pids, dependency_cids, colorvals)

    def idxFromRaw(self, pid, cid, sizes):
        idx = 0
        for i in self.fixedRange(pid-1):
            idx += sizes[i]
        idx += cid
        return idx - 1 # zero-indexed

    def PIDFromIdx(self, idx, sizes):
        parent_id = 0
        size = 0
        while size < idx + 1:
            parent_id += 1
            size += sizes[parent_id]
        return parent_id

    def loadSpecs(self, speclinelist): # solve the scheduling linear programming problem!
        num_tasks = 0 # N
        task_sizes = dict()
        task_names = list()
        task_times = list()
        raw_depend = list()

        for specline in speclinelist:
            parent_id, child_id, text, time_length, dep_pids, dep_cids, colorvals = self.parseLine(specline)

            if not parent_id is None:
                if child_id is None:
                    self.parent_names.append(text)
                    self.max_parent_id += 1
                    if colorvals is None:
                        self.colors.append((self.colorName(self.max_parent_id), self.colorFunc(self.max_parent_id)))
                    else:
                        self.colors.append((self.colorName(self.max_parent_id), colorvals))
                else:
                    num_tasks += 1
                    if not parent_id in task_sizes:
                        task_sizes[parent_id] = 1
                    else:
                        task_sizes[parent_id] += 1
                    task_names.append(text)
                    task_times.append(time_length)
                    for dep_pid, dep_cid in zip(dep_pids, dep_cids):
                        raw_depend.append(((parent_id, child_id),(dep_pid, dep_cid)))

        t = np.zeros((num_tasks, 1))
        max_possible_time = 0
        for i, task_time in enumerate(task_times):
            max_possible_time += 1.0 + task_time
            t[i, 0] = task_time

        lu = list()
        for i in range(2 * num_tasks):
            lu.append((1.0, max_possible_time))

        num_dependencies = len(raw_depend)
        
        c = np.vstack((np.zeros((num_tasks, 1)), np.ones((num_tasks, 1))))
        N = np.hstack((-np.eye(num_tasks), np.eye(num_tasks)))
        M = np.zeros((num_dependencies, 2 * num_tasks))
        g = np.ones((num_dependencies, 1)) * -1.0

        for i, raw_dep in enumerate(raw_depend):
            k_x = self.idxFromRaw(raw_dep[0][0], raw_dep[0][1], task_sizes)
            k_y = self.idxFromRaw(raw_dep[1][0], raw_dep[1][1], task_sizes)
            self.links.append((k_y, k_x))
            M[i, k_x] = -1.0
            M[i, k_y + num_tasks] = 1.0

        # Solve the scheduling problem
        res = linprog(c, A_ub=M, b_ub=g, A_eq=N, b_eq=t, bounds=lu, method='revised simplex')

        for i in range(num_tasks):
            start_time = 2*int(res.x[i])-1
            end_time   = 2*int(res.x[num_tasks+i])-1
            if end_time > self.max_time_idx:
                self.max_time_idx = end_time
            self.bars.append((self.colorName(self.PIDFromIdx(i, task_sizes)), task_names[i], start_time, end_time))

    def getBound(self):
        return self.max_time_idx

    def getBars(self):
        return self.bars

    def getLinks(self):
        return self.links

    def generateFigs(self):
        for i in self.fixedRange(self.max_parent_id):
            figname = self.colorName(i)
            self.figs.append('%s.pdf' % figname)
            svgfullname = os.path.join(self.figdir, '%s.svg' % figname)
            pdffullname = os.path.join(self.figdir, '%s.pdf' % figname)
            with open(self.blanksvg, 'r') as reffile, open(svgfullname, 'w') as outsvg:
                for line_no, line in enumerate(reffile):
                    if line_no == 23:
                        outsvg.write(line.replace('ffffff', self.fullColorHex(self.colors[i-1][1])))
                    else:
                        outsvg.write(line)
            subprocess.call([self.pdfconv, svgfullname, pdffullname],
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
            os.remove(svgfullname)

    def getFigs(self):
        return self.figs

    def getLabeledFigs(self):
        labeledfigs = list()
        figs = self.getFigs()
        for i in range(self.max_parent_id):
            labeledfigs.append((figs[i], self.parent_names[i]))
        return labeledfigs

def main():
    specfile = sys.argv[1]
    blanksvg = sys.argv[2]
    figdir = sys.argv[3]
    pdfconv = sys.argv[4]
    parser = SpecParser(blanksvg=blanksvg, figdir=figdir, pdfconv=pdfconv)
    specname = os.path.splitext(os.path.basename(specfile))[0]

    with open(specfile, 'r') as infile:
        parser.loadSpecs(infile.read().split('\n'))

    parser.generateFigs()

    preamble1 = """\\documentclass{article}
    \\usepackage{graphicx}
    \\usepackage[a4paper,margin=0.25in]{geometry}
    \\usepackage{pgfgantt}
    \\usepackage{xcolor}

    """

    preamble2 = """
    \\begin{document}
    \\pagestyle{empty}

    """

    with open('%s.tex' % specname, 'w') as outfile:
        outfile.write(preamble1)
        for color in parser.getColors():
            outfile.write("\\definecolor{%s}{RGB}{%d,%d,%d}\n" % (color[0], color[1][0], color[1][1], color[1][2]))
        outfile.write(preamble2)
        for labeled_fig in parser.getLabeledFigs():
            outfile.write("\\includegraphics[width=10px]{%s} %s\n\n" % labeled_fig)
        outfile.write("\n\\vspace{0.5cm}\n\n\\begin{ganttchart}[hgrid,vgrid]{1}{%d}\n" % parser.getBound())
        bars = parser.getBars()
        num_bars = len(bars)
        for i, bar in enumerate(bars):
            if i == num_bars - 1:
                outfile.write("\\ganttbar[bar/.append style={fill=%s}]{%s}{%d}{%d}\n" % bar)
            else:
                outfile.write("\\ganttbar[bar/.append style={fill=%s}]{%s}{%d}{%d} \\\\\n" % bar)
        for link in parser.getLinks():
            outfile.write("\\ganttlink{elem%d}{elem%d}\n" % link)
        outfile.write("\\end{ganttchart}\n\n\\end{document}")

    print(' '.join(parser.getFigs()))

if __name__ == '__main__':
    main()
