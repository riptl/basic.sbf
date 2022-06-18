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
        "basic.so",
    ]
    input_obj = {
        "accounts": [
            {
                "key": [42] * 32,
                "owner": [0] * 32,
                "is_signer": True,
                "is_writable": True,
                "lamports": 1000,
            }
        ],
        "instruction_data": h2i(unit_case["input"]),
    }
    subprocess.run(
        cmd, text=True, check=True, input=json.dumps(input_obj), stderr=subprocess.PIPE
    )
