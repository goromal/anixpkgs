import sys
import re

class SMFStatus:
    def __init__(self, success, msg):
        self.success = success
        self.msg = msg
        
    def isSuccess(self):
        return self.success
        
    @staticmethod
    def OK():
        return SMFStatus(True, "")
        
    @staticmethod
    def FAIL(msg):
        return SMFStatus(False, msg)
        
    def __repr__(self):
        success_msg = "SUCCESS" if self.success else "FAILED"
        status_msg = "" if self.msg == "" else f": {self.msg}"
        return f"{success_msg}{status_msg}"
        
class ClefTypes:
    TREBLE = 0
    BASS = 1
CLEFTYPESTR = {
    ClefTypes.TREBLE: "",
    ClefTypes.BASS: "bass"
}

NOTES_IN_OCTAVE = 7

class NoteTypes:
    Z = -1
    C = 0
    D = 1
    E = 2
    F = 3
    G = 4
    A = 5
    B = 6
NOTETYPESTR = {
    NoteTypes.Z: "-",
    NoteTypes.C: "C",
    NoteTypes.D: "D",
    NoteTypes.E: "E",
    NoteTypes.F: "F",
    NoteTypes.G: "G",
    NoteTypes.A: "A",
    NoteTypes.B: "B"
}
NOTETYPEKEYS = dict((v,k) for k,v in NOTETYPESTR.items())

class Accidentals:
    FLAT = -1
    NATURAL = 0
    SHARP = 1
ACCSTR = {
    Accidentals.FLAT: "b",
    Accidentals.NATURAL: "",
    Accidentals.SHARP: "#"
}
ACCSTR2 = {
    Accidentals.FLAT: "_",
    Accidentals.NATURAL: "",
    Accidentals.SHARP: "^"
}

class Note:
    def __init__(self, note: NoteTypes, acc: Accidentals = Accidentals.NATURAL):
        self.note = note
        self.acc = acc
        
    def __repr__(self):
        if self.note == NoteTypes.Z:
            return "-"
        else:
            return f"{NOTETYPESTR[self.note]}{ACCSTR[self.acc]}"

class NoteLengths:
    TWELFTH = 0
    EIGHTH = 1
    QUARTER = 2
    HALF = 3
    WHOLE = 4
NLSTR = {
    NoteLengths.TWELFTH: "1/12", # /3
    NoteLengths.EIGHTH: "1/8",   # /2
    NoteLengths.QUARTER: "1/4",  # 
    NoteLengths.HALF: "1/2",     # 2
    NoteLengths.WHOLE: "1"       # 4
}
NLKEYS = {
    "/3": NoteLengths.TWELFTH,
    "/2": NoteLengths.EIGHTH,
    "": NoteLengths.QUARTER,
    "2": NoteLengths.HALF,
    "4": NoteLengths.WHOLE
}
NLSTR2 = dict((v,k) for k,v in NLKEYS.items())
NLNUM = {
    NoteLengths.TWELFTH: 1./12.,
    NoteLengths.EIGHTH: 1./8.,
    NoteLengths.QUARTER: 1./4.,
    NoteLengths.HALF: 1./2.,
    NoteLengths.WHOLE: 1.,
}

class SMFToken:
    def __init__(self, **kwargs):
        self.length = kwargs["length"] if "length" in kwargs else NoteLengths.QUARTER
        self.notes = kwargs["notes"] if "notes" in kwargs else [Note(NoteTypes.C, Accidentals.NATURAL)]
        self.octaves = kwargs["octaves"] if "octaves" in kwargs else [4]*len(self.notes)
        assert len(self.notes) == len(self.octaves)
        
    def _to_abc_ind(self, note, octave, length):
        if note.note == NoteTypes.Z:
            abc_acc = ""
            abc_note = "z"
        else:
            abc_acc = ACCSTR2[note.acc]
            if octave <= 4:
                abc_note = NOTETYPESTR[note.note]
                if octave < 4:
                    abc_note += "," * (4 - octave)
            else:
                abc_note = NOTETYPESTR[note.note].lower()
                if octave > 5:
                    abc_note += "'" * (octave - 5)
        abc_len = NLSTR2[length]
        return f"{abc_acc}{abc_note}{abc_len}"
        
    def toABC(self):
        if len(self.notes) > 1:
            abc_inds = [self._to_abc_ind(n, o, self.length) for n, o in zip(self.notes, self.octaves)]
            abc_inds_str = "".join(abc_inds)
            abc_str = f"[{abc_inds_str}]"
        else:
            abc_str = self._to_abc_ind(self.notes[0], self.octaves[0], self.length)
        return NLNUM[self.length], abc_str
        
    def toVal(self):
        if NoteTypes.Z in self.notes:
            return False, 0.0
        vals = [1.0 * o * NOTES_IN_OCTAVE + 1.0 + n.note + 0.5 * n.acc for o, n in zip(self.octaves, self.notes)]
        return True, 1.0 * sum(vals) / len(vals)
    
    def __repr__(self):
        return f"({NLSTR[self.length]})<" + " ".join([f"{n}{o}" for n, o in zip(self.notes, self.octaves)]) + ">"
        
MIDDLE_C_TOKEN = SMFToken()

class SMFParser(object):
    def __init__(self):
        self._reset()
        
    def parseSMF(self, fname) -> SMFStatus:
        self._reset()
        try:
            smffile = open(fname, "r")
        except FileNotFoundError:
            return SMFStatus.FAIL(f"File {fname} not found")
        except OSError:
            return SMFStatus.FAIL(f"OS error while trying to open {fname}")
        except Exception as err:
            return SMFStatus.FAIL(f"Unexpected error opening {fname}: {err}")
        else:
            with smffile:
                gather_status = self._gather_tokens(smffile)
                if not gather_status.isSuccess():
                    return gather_status
        return SMFStatus.OK()
        
    def dumpABC(self, fname, tempo=100) -> SMFStatus:
        try:
            abcfile = open(fname, "w")
        except OSError:
            return SMFStatus.FAIL(f"OS error while trying to open {fname} for writing")
        except Exception as err:
            return SMFStatus.FAIL(f"Unexpected error opening {fname}: {err}")
        else:
            with abcfile:
                voices = [voice_id for voice_id in self._tokens.keys()]
                if len(voices) == 0:
                    return SMFStatus.FAIL("Cannot dump an abc file with no stored music notes")
                header_status = self._write_abc_header(abcfile, voices, tempo)
                if not header_status.isSuccess():
                    return header_status
                abcfile.write("%\n")
                abc_voice_lines = {}
                for voice in voices:
                    voice_lines_res, voice_lines = self._produce_abc_voice_lines(voice)
                    if not voice_lines_res.isSuccess():
                        return voice_lines_res
                    abc_voice_lines[voice] = voice_lines
                max_voice_line_length = max([len(abc_voice_lines[voice]) for voice in voices])
                for i in range(max_voice_line_length):
                    for voice in voices:
                        if i < len(abc_voice_lines[voice]):
                            abcfile.write(f"{abc_voice_lines[voice][i]}\n")
        return SMFStatus.OK()
        
    def _write_abc_header(self, abcfile, voices, tempo):
        if tempo < 0 or tempo > 400:
            return SMFStatus.FAIL(f"Invalid quarter note tempo provided: {tempo}")
        abcfile.write("X:1\n")
        abcfile.write("T:Auto-Generated Tune from SMF\n")
        abcfile.write("M:4/4\n")
        abcfile.write("L:1/4\n")
        abcfile.write(f"Q:1/4={tempo}\n")
        key = self._detect_key_as_abcstr(voices)
        abcfile.write(f"K:{key}\n")
        for voice in voices:
            clef_type = self._detect_voice_clef(voice)
            abcfile.write(f"V:{voice} {CLEFTYPESTR[clef_type]}\n")
        return SMFStatus.OK()
        
    def _produce_abc_voice_lines(self, voice):
        STANZAS_PER_LINE = 3
        voice_lines = []
        abc_lens = []
        abc_strs = []
        for token in self._tokens[voice]:
            abc_len, abc_str = token.toABC()
            abc_lens.append(abc_len)
            abc_strs.append(abc_str)
        stanzas_res, stanzas = self._get_stanzas(abc_lens, abc_strs)
        if not stanzas_res.isSuccess():
            return SMFStatus.FAIL(f"Stanzas creation error for voice {voice}: {stanzas_res.msg}"), []
        num_lines, num_leftover_stanzas = divmod(len(stanzas), STANZAS_PER_LINE)
        if num_leftover_stanzas > 0:
            num_lines += 1
        for i in range(num_lines):
            voice_line = f"[V:{voice}] "
            if i == num_lines - 1 and num_leftover_stanzas > 0:
                num_line_stanzas = num_leftover_stanzas
            else:
                num_line_stanzas = STANZAS_PER_LINE
            for j in range(num_line_stanzas):
                voice_line += f"{stanzas[STANZAS_PER_LINE*i+j]}|"
            voice_lines.append(voice_line)
        return SMFStatus.OK(), voice_lines
        
    def _get_stanzas(self, lens, strs):
        running_len = 0.0
        stanzas = []
        current_stanza = ""
        for l, s in zip(lens, strs):
            running_len += l
            current_stanza += f" {s}"
            if abs(running_len - 1.0*(len(stanzas)+1)) < 1e-4:
                stanzas.append(current_stanza)
                current_stanza = ""
            elif running_len - 1.0*(len(stanzas)+1) > 1e-4:
                return SMFStatus.FAIL("Invalid stanza note length groupings"), []
        if current_stanza != "":
            stanzas.append(current_stanza)
        return SMFStatus.OK(), stanzas
        
    def _detect_voice_clef(self, voice):
        token_vals = []
        for token in self._tokens[voice]:
            valid, val = token.toVal()
            if valid:
                token_vals.append(val)
        if len(token_vals) == 0:
            return ClefTypes.TREBLE
        avg_token_val = sum(token_vals) / len(token_vals)
        if avg_token_val > MIDDLE_C_TOKEN.toVal()[1]:
            return ClefTypes.TREBLE
        else:
            return ClefTypes.BASS
            
    def _detect_key_as_abcstr(self, voices):
        return "C" # For now
        
    def _gather_tokens(self, fhandle) -> SMFStatus:
        current_voice = 1
        for i, line in enumerate(fhandle):
            line_no = i + 1
            raw_tokens = line.split()
            for raw_token in raw_tokens:
                if "#" in raw_token:
                    break
                else:
                    if ":" in raw_token:
                        voice_res = re.match(r"(\d+):", raw_token)
                        if not voice_res:
                            return SMFStatus.FAIL(f"Mal-formed voice specification on line {line_no}: {raw_token}")
                        else:
                            current_voice = int(voice_res.groups()[0])
                    else:
                        token, token_status = self._make_token(line_no, raw_token)
                        if not token_status.isSuccess():
                            return token_status
                        if current_voice in self._tokens:
                            self._tokens[current_voice].append(token)
                        else:
                            self._tokens[current_voice] = [token]
        return SMFStatus.OK()
        
    def _make_token(self, line_no, raw_token):
        length_res = re.match(r"(/?\d)", raw_token)
        if length_res:
            length_key = length_res.groups()[0]
            if length_key not in NLKEYS:
                return SMFToken(), SMFStatus.FAIL(f"Unrecognized token length specification on line {line_no}: {length_key}")
            else:
                length = NLKEYS[length_key]
                raw_token = raw_token[len(length_key):]
        else:
            length = NoteLengths.QUARTER
        notes = []
        octaves = []
        while raw_token != "":
            token_res = re.match(r"(-|((a|A|b|B|c|C|d|D|e|E|f|F|g|G)(\^|_)?(1|2|3|4|5|6|7|8)?))", raw_token)
            if token_res:
                token_str = token_res.groups()[0]
                if token_str == "-":
                    notes.append(Note(NoteTypes.Z))
                    octaves.append(0)
                else:
                    note_type = NOTETYPEKEYS[re.search(r"(\w)", token_str).groups()[0].upper()]
                    if "^" in token_str:
                        acc = Accidentals.SHARP
                    elif "_" in token_str:
                        acc = Accidentals.FLAT
                    else:
                        acc = Accidentals.NATURAL
                    note = Note(note_type, acc)
                    octave_res = re.search(r"(\d)", token_str)
                    if octave_res:
                        octave = int(octave_res.groups()[0])
                    else:
                        octave = 4
                    if not self._is_on_keyboard(note, octave):
                        return SMFStatus.FAIL(f"Token specified a note that is not on the 88-note standard keyboard: {raw_token}")
                    notes.append(note)
                    octaves.append(octave)
                raw_token = raw_token[len(token_str):]
            else:
                return SMFToken(), SMFStatus.FAIL(f"Mal-formed token on line {line_no}: {raw_token}")
        if len(notes) == 0:
            return SMFToken(), SMFStatus.FAIL(f"No note provided in token on line {line_no}: {raw_token}")
        return SMFToken(length=length, notes=notes, octaves=octaves), SMFStatus.OK()
    
    def _is_on_keyboard(self, note, octave):
        if not (0 <= octave <= 8):
            return False
        if octave == 0 and note.note != NoteTypes.A and note.note != NoteTypes.B:
            return False
        if octave == 8 and note.note != NoteTypes.C:
            return False
        if octave == 8 and note.note == NoteTypes.C and note.acc == Accidentals.SHARP:
            return False
        if octave == 0 and note.note == NoteTypes.A and note.acc == Accidentals.FLAT:
            return False
        return True
    
    def _reset(self):
        self._tokens = {}    

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(SMFStatus.FAIL("SMF -> ABC converter requires an input and output file specification"))
        sys.exit(1)
    parser = SMFParser()
    parse_res = parser.parseSMF(sys.argv[1])
    if not parse_res.isSuccess():
        print(parse_res)
        sys.exit(1)
    dump_res = parser.dumpABC(sys.argv[2])
    if not dump_res.isSuccess():
        print(dump_res)
        sys.exit(1)
