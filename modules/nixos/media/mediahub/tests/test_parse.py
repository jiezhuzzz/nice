# tests/test_parse.py
from mediahub.parse import parse_release


def test_project_hail_mary():
    f = parse_release(
        "挽救计划.Project.Hail.Mary.2026.2160p.WEB-DL.DDP5.1.Atmos.H265.HDR.DV-DIY@HDSWEB"
    )
    assert f.resolution == "2160p"
    assert f.source == "WEB-DL"
    assert f.codec == "H.265"
    assert "HDR" in f.hdr
    assert "DV" in f.hdr
    assert "Atmos" in f.audio
    assert f.year == 2026
    assert f.group is not None and "HDSWEB" in f.group


def test_bleach_s2_bdrip():
    f = parse_release("[2023][Bleach Sennen Kessen Hen S2][BDRIP][1080P][14-26+SP]")
    assert f.resolution == "1080p"
    assert f.source == "BDRip"
    assert f.season == 2


def test_yumi_s02_webdl():
    f = parse_release(
        "[柔美的细胞小将 第二季].Yumi's.Cells.2022.S02.Complete.1080p.IQ.WEB-DL.H264.AAC-UBWEB"
    )
    assert f.resolution == "1080p"
    assert f.source == "WEB-DL"
    assert f.codec == "H.264"
    assert "AAC" in f.audio
    assert f.season == 2
    assert f.group == "UBWEB"


def test_jav_code_has_no_quality():
    f = parse_release("JUX-455")
    assert f.resolution is None
    assert f.source is None
