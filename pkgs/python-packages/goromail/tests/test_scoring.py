from goromail.cli import eating_discipline_level

# grams giving coverage 1.25 at consumed=1000: 9*50 + 4*100 + 4*100 = 1250
COV_OK = (50, 100, 100)      # coverage = 1.25 (>= 0.80) at consumed=1000
COV_LOW = (10, 10, 10)       # coverage = 0.17 (< 0.80) at consumed=1000


def n(grams, fat_pct):
    return (grams[0], grams[1], grams[2], fat_pct)


# --- no nutrients: surplus-only ---
def test_none_full():   assert eating_discipline_level(900, 1000, None) == 2   # surplus -100
def test_none_partial():assert eating_discipline_level(1100, 1000, None) == 1  # surplus +100
def test_none_no():     assert eating_discipline_level(1300, 1000, None) == 0  # surplus +300


# --- below coverage gate: fat% ignored, surplus-only ---
def test_below_gate_ignores_fat():
    # great surplus (level 2) but terrible fat% (90) and low coverage -> stays 2
    assert eating_discipline_level(1000, 1100, n(COV_LOW, 90.0)) == 2


# --- above gate: average(surplus_level, fat_level), round half up ---
def test_gate_full_and_good_fat():      # surplus 2, fat 2 -> avg 2 -> 2
    assert eating_discipline_level(1000, 1100, n(COV_OK, 25.0)) == 2
def test_gate_full_and_ok_fat():        # surplus 2, fat 1 -> avg 1.5 -> 2
    assert eating_discipline_level(1000, 1100, n(COV_OK, 35.0)) == 2
def test_gate_full_and_bad_fat():       # surplus 2, fat 0 -> avg 1.0 -> 1
    assert eating_discipline_level(1000, 1100, n(COV_OK, 45.0)) == 1
def test_gate_partial_and_bad_fat():    # surplus 1, fat 0 -> avg 0.5 -> 1
    assert eating_discipline_level(1000, 900, n(COV_OK, 45.0)) == 1
def test_gate_no_and_bad_fat():         # surplus 0, fat 0 -> avg 0 -> 0
    assert eating_discipline_level(1000, 700, n(COV_OK, 45.0)) == 0
def test_gate_no_and_good_fat():        # surplus 0, fat 2 -> avg 1.0 -> 1
    assert eating_discipline_level(1000, 700, n(COV_OK, 25.0)) == 1


# --- guard: consumed 0 does not divide by zero ---
def test_consumed_zero():
    assert eating_discipline_level(0, 100, n(COV_OK, 90.0)) == 2  # surplus -100


# --- surplus threshold boundaries (nutrients=None) ---
def test_surplus_zero_is_full():      # surplus == 0 -> full
    assert eating_discipline_level(1000, 1000, None) == 2
def test_surplus_200_is_partial():    # surplus == 200 (<=200) -> partial
    assert eating_discipline_level(1200, 1000, None) == 1
def test_surplus_201_is_no():         # surplus == 201 (>200) -> no
    assert eating_discipline_level(1201, 1000, None) == 0


# --- coverage gate boundary at exactly 0.80 ---
# grams (40, 80, 30): tracked = 9*40 + 4*80 + 4*30 = 800
def test_coverage_exactly_080_passes_gate():
    # consumed=1000 -> coverage 0.80 (>= 0.80) -> gate PASSES -> blend.
    # surplus -100 (level 2), fat_pct 90 (fat_level 0) -> avg 1.0 -> int(1.5) -> 1
    assert eating_discipline_level(1000, 1100, (40, 80, 30, 90.0)) == 1
def test_coverage_just_below_080_falls_back():
    # consumed=1001 -> coverage 0.799 (< 0.80) -> gate FAILS -> surplus-only.
    # surplus 1001-1101 = -100 (level 2), fat_pct ignored -> 2
    assert eating_discipline_level(1001, 1101, (40, 80, 30, 90.0)) == 2


from goromail.cli import _credit_enum
from aapis.tactical.v1 import tactical_pb2


def test_credit_enum_mapping():
    T = tactical_pb2.SurveyQuestionResultType
    assert _credit_enum(0) == T.SURVEY_QUESTION_RESULT_TYPE_NO_CREDIT
    assert _credit_enum(1) == T.SURVEY_QUESTION_RESULT_TYPE_PARTIAL_CREDIT
    assert _credit_enum(2) == T.SURVEY_QUESTION_RESULT_TYPE_FULL_CREDIT
