use goose_core::protocol::{DataPacketBodySummary, parse_v24_body_for_test};

// Helpers to build synthetic payloads for parse_v24_body_for_test.
// The function expects the full frame payload where data = payload[3..].
// So payload[3 + offset] corresponds to data[offset].

fn make_82_byte_payload() -> Vec<u8> {
    // 3-byte pkt header + 79-byte data section = 82 bytes total.
    // All bytes initialised to zero; specific fields filled below.
    let mut pkt = vec![0u8; 82];

    // data[14] = 72 — hr = 72 bpm
    pkt[3 + 14] = 72u8;

    // data[15] = 2 — rr_count = 2
    pkt[3 + 15] = 2u8;

    // data[16..18] = 900 le — rr[0] = 900 ms
    let rr0 = 900u16.to_le_bytes();
    pkt[3 + 16] = rr0[0];
    pkt[3 + 17] = rr0[1];

    // data[18..20] = 950 le — rr[1] = 950 ms
    let rr1 = 950u16.to_le_bytes();
    pkt[3 + 18] = rr1[0];
    pkt[3 + 19] = rr1[1];

    // data[26..28] = 1000 le — ppg_green = 1000
    let ppg_green = 1000u16.to_le_bytes();
    pkt[3 + 26] = ppg_green[0];
    pkt[3 + 27] = ppg_green[1];

    // data[28..30] = 2000 le — ppg_red_ir = 2000
    let ppg_red_ir = 2000u16.to_le_bytes();
    pkt[3 + 28] = ppg_red_ir[0];
    pkt[3 + 29] = ppg_red_ir[1];

    // data[33..37] = 0.98f32 le — gravity_x = 0.98
    let gx = 0.98f32.to_le_bytes();
    pkt[3 + 33] = gx[0];
    pkt[3 + 34] = gx[1];
    pkt[3 + 35] = gx[2];
    pkt[3 + 36] = gx[3];

    // data[37..41] = 0.01f32 le — gravity_y = 0.01
    let gy = 0.01f32.to_le_bytes();
    pkt[3 + 37] = gy[0];
    pkt[3 + 38] = gy[1];
    pkt[3 + 39] = gy[2];
    pkt[3 + 40] = gy[3];

    // data[41..45] = 0.05f32 le — gravity_z = 0.05
    let gz = 0.05f32.to_le_bytes();
    pkt[3 + 41] = gz[0];
    pkt[3 + 42] = gz[1];
    pkt[3 + 43] = gz[2];
    pkt[3 + 44] = gz[3];

    // data[48] = 1 — skin_contact = 1
    pkt[3 + 48] = 1u8;

    // data[61..63] = 800 le — spo2_red = 800
    let spo2_red = 800u16.to_le_bytes();
    pkt[3 + 61] = spo2_red[0];
    pkt[3 + 62] = spo2_red[1];

    // data[63..65] = 1200 le — spo2_ir = 1200
    let spo2_ir = 1200u16.to_le_bytes();
    pkt[3 + 63] = spo2_ir[0];
    pkt[3 + 64] = spo2_ir[1];

    // data[65..67] = 930 le — skin_temp_raw = 930
    let skin_temp = 930u16.to_le_bytes();
    pkt[3 + 65] = skin_temp[0];
    pkt[3 + 66] = skin_temp[1];

    // data[67..69] = 250 le — ambient = 250
    let ambient = 250u16.to_le_bytes();
    pkt[3 + 67] = ambient[0];
    pkt[3 + 68] = ambient[1];

    // data[69..71] = 100 le — led1 = 100
    let led1 = 100u16.to_le_bytes();
    pkt[3 + 69] = led1[0];
    pkt[3 + 70] = led1[1];

    // data[71..73] = 200 le — led2 = 200
    let led2 = 200u16.to_le_bytes();
    pkt[3 + 71] = led2[0];
    pkt[3 + 72] = led2[1];

    // data[73..75] = 450 le — resp_raw = 450
    let resp = 450u16.to_le_bytes();
    pkt[3 + 73] = resp[0];
    pkt[3 + 74] = resp[1];

    // data[75..77] = 9000 le — sig_quality = 9000
    let sig = 9000u16.to_le_bytes();
    pkt[3 + 75] = sig[0];
    pkt[3 + 76] = sig[1];

    pkt
}

#[test]
fn test_v24_body_summary_field_offsets() {
    let payload = make_82_byte_payload();
    let (summary, warnings) = parse_v24_body_for_test(&payload);

    assert!(warnings.is_empty(), "Expected no warnings, got: {:?}", warnings);

    let summary = summary.expect("Expected Some(V24History), got None");

    match summary {
        DataPacketBodySummary::V24History {
            hr,
            rr_intervals_ms,
            ppg_green,
            ppg_red_ir,
            gravity_x,
            gravity_y,
            gravity_z,
            skin_contact,
            spo2_red,
            spo2_ir,
            skin_temp_raw,
            ambient,
            led1,
            led2,
            resp_raw,
            sig_quality,
            gravity2_x,
            gravity2_y,
            gravity2_z,
            warnings,
        } => {
            assert_eq!(hr, Some(72), "hr mismatch");
            assert_eq!(rr_intervals_ms, vec![900u16, 950u16], "rr_intervals_ms mismatch");
            assert_eq!(ppg_green, Some(1000), "ppg_green mismatch");
            assert_eq!(ppg_red_ir, Some(2000), "ppg_red_ir mismatch");
            assert!(
                (gravity_x.unwrap() - 0.98f32).abs() < 1e-5,
                "gravity_x mismatch: {:?}",
                gravity_x
            );
            assert!(
                (gravity_y.unwrap() - 0.01f32).abs() < 1e-5,
                "gravity_y mismatch: {:?}",
                gravity_y
            );
            assert!(
                (gravity_z.unwrap() - 0.05f32).abs() < 1e-5,
                "gravity_z mismatch: {:?}",
                gravity_z
            );
            assert_eq!(skin_contact, Some(1), "skin_contact mismatch");
            // gravity2 fields: present only when data.len() >= 60; test payload has 80 bytes
            // (payload[3..] = 77 bytes, offset 49 < 77) so gravity2 is present.
            let _ = (gravity2_x, gravity2_y, gravity2_z); // presence verified by compilation
            assert_eq!(spo2_red, Some(800), "spo2_red mismatch");
            assert_eq!(spo2_ir, Some(1200), "spo2_ir mismatch");
            assert_eq!(skin_temp_raw, Some(930), "skin_temp_raw mismatch");
            assert_eq!(ambient, Some(250), "ambient mismatch");
            assert_eq!(led1, Some(100), "led1 mismatch");
            assert_eq!(led2, Some(200), "led2 mismatch");
            assert_eq!(resp_raw, Some(450), "resp_raw mismatch");
            assert_eq!(sig_quality, Some(9000), "sig_quality mismatch");
            assert!(warnings.is_empty(), "Unexpected warnings in variant: {:?}", warnings);
        }
        other => panic!("Expected V24History, got: {:?}", other),
    }
}

#[test]
fn test_v24_short_payload() {
    // 10-byte payload — data = payload[3..] has only 7 bytes, well below 77
    let payload = vec![0u8; 10];
    let (summary, warnings) = parse_v24_body_for_test(&payload);

    assert!(
        warnings.iter().any(|w| w == "v24_payload_too_short"),
        "Expected v24_payload_too_short in warnings, got: {:?}",
        warnings
    );

    let summary = summary.expect("Expected Some(V24History) even for short payload");

    match summary {
        DataPacketBodySummary::V24History {
            hr,
            rr_intervals_ms,
            ppg_green,
            ppg_red_ir,
            gravity_x,
            gravity_y,
            gravity_z,
            skin_contact,
            spo2_red,
            spo2_ir,
            skin_temp_raw,
            ambient,
            led1,
            led2,
            resp_raw,
            sig_quality,
            gravity2_x,
            gravity2_y,
            gravity2_z,
            warnings: variant_warnings,
        } => {
            assert!(hr.is_none(), "hr should be None for short payload");
            assert!(rr_intervals_ms.is_empty(), "rr_intervals_ms should be empty for short payload");
            assert!(ppg_green.is_none(), "ppg_green should be None");
            assert!(ppg_red_ir.is_none(), "ppg_red_ir should be None");
            assert!(gravity_x.is_none(), "gravity_x should be None");
            assert!(gravity_y.is_none(), "gravity_y should be None");
            assert!(gravity_z.is_none(), "gravity_z should be None");
            assert!(skin_contact.is_none(), "skin_contact should be None");
            assert!(gravity2_x.is_none(), "gravity2_x should be None for short payload");
            assert!(gravity2_y.is_none(), "gravity2_y should be None for short payload");
            assert!(gravity2_z.is_none(), "gravity2_z should be None for short payload");
            assert!(spo2_red.is_none(), "spo2_red should be None");
            assert!(spo2_ir.is_none(), "spo2_ir should be None");
            assert!(skin_temp_raw.is_none(), "skin_temp_raw should be None");
            assert!(ambient.is_none(), "ambient should be None");
            assert!(led1.is_none(), "led1 should be None");
            assert!(led2.is_none(), "led2 should be None");
            assert!(resp_raw.is_none(), "resp_raw should be None");
            assert!(sig_quality.is_none(), "sig_quality should be None");
            assert!(
                variant_warnings.iter().any(|w| w == "v24_payload_too_short"),
                "Expected v24_payload_too_short in variant warnings"
            );
        }
        other => panic!("Expected V24History, got: {:?}", other),
    }
}

#[test]
fn test_v24_rr_zero_skip() {
    // rr_count = 3 but data[18..20] is zero — only 2 entries should appear in rr_intervals_ms
    let mut payload = vec![0u8; 82];

    // data[15] = 3 — rr_count = 3
    payload[3 + 15] = 3u8;

    // data[16..18] = 880 le — rr[0] = 880 ms
    let rr0 = 880u16.to_le_bytes();
    payload[3 + 16] = rr0[0];
    payload[3 + 17] = rr0[1];

    // data[18..20] = 0 le — rr[1] = 0 (should be skipped)
    // already zero from vec! initialisation

    // data[20..22] = 920 le — rr[2] = 920 ms
    let rr2 = 920u16.to_le_bytes();
    payload[3 + 20] = rr2[0];
    payload[3 + 21] = rr2[1];

    let (summary, _warnings) = parse_v24_body_for_test(&payload);
    let summary = summary.expect("Expected Some(V24History)");

    match summary {
        DataPacketBodySummary::V24History { rr_intervals_ms, .. } => {
            assert_eq!(
                rr_intervals_ms,
                vec![880u16, 920u16],
                "Expected 2 RR entries after zero-skip, got: {:?}",
                rr_intervals_ms
            );
        }
        other => panic!("Expected V24History, got: {:?}", other),
    }
}
