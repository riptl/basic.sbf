import json
import pytest
import subprocess
import yaml


def load_unit_cases():
    with open("tests.yml") as tests_file:
        for case in yaml.safe_load(tests_file):
            yield pytest.param(case, id=case["name"])


def pytest_generate_tests(metafunc):
    for fixture in metafunc.fixturenames:
        if fixture == "unit_case":
            metafunc.parametrize(fixture, load_unit_cases())


def b2i(buf: bytes) -> list[int]:
    return [int(b) for b in buf]


def h2i(s: str) -> list[str]:
    return b2i(s.encode("utf-8"))


def test_program(unit_case):
    cmd = [
        "rbpf-cli",
        "--input=/dev/stdin",
        "--use=interpreter",
        "--output=json-compact",
        # "--trace",
        "basic.so",
    ]
    input_obj = {
        "accounts": [
            {
                "key": [0x69] * 32,
                "owner": [0] * 32,
                "is_signer": True,
                "is_writable": True,
                "lamports": 1000,
                "data": [0] * 8192,
            }
        ],
        "instruction_data": h2i(unit_case["input"]),
    }
    process = subprocess.run(
        cmd,
        text=True,
        check=True,
        input=json.dumps(input_obj),
        capture_output=True,
    )
    stdout = process.stdout
    result = json.loads(stdout)
    log = "\n".join(result.get("log", []))
    result_str = result["result"]
    if result_str.startswith("Err("):
        assert unit_case.get("result", "") == result_str
    assert unit_case.get("log", "").strip() == log.strip()
