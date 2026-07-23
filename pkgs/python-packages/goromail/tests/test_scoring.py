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
