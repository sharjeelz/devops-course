from linkly_api.codes import CODE_RE, new_code


def test_codes_are_seven_url_safe_characters_and_vary():
    codes = {new_code() for _ in range(200)}
    assert all(CODE_RE.fullmatch(c) for c in codes)
    assert len(codes) == 200
