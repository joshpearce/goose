// Unconverted test .unwrap() calls remain in this file; shield removed in Plan 4.
#![allow(clippy::unwrap_used)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum DeviceKind {
    Whoop4,
    Whoop5,
    HrMonitor,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub struct DeviceCapabilities {
    pub wire_protocol: String,
    pub historical_sync: String,
    pub battery_via_r22: bool,
    pub battery_via_event48: bool,
    pub battery_via_cmd26: bool,
    pub r22_realtime: bool,
}

impl DeviceCapabilities {
    pub fn for_kind(kind: DeviceKind) -> Self {
        match kind {
            DeviceKind::Whoop4 => Self {
                wire_protocol: "gen4".to_string(),
                historical_sync: "page_sequence".to_string(),
                battery_via_r22: false,
                battery_via_event48: true,
                battery_via_cmd26: true,
                r22_realtime: false,
            },
            DeviceKind::Whoop5 => Self {
                wire_protocol: "gen5".to_string(),
                historical_sync: "stream".to_string(),
                battery_via_r22: true,
                battery_via_event48: true,
                battery_via_cmd26: true,
                r22_realtime: true,
            },
            DeviceKind::HrMonitor => Self {
                wire_protocol: "gen5".to_string(),
                historical_sync: "stream".to_string(),
                battery_via_r22: false,
                battery_via_event48: false,
                battery_via_cmd26: false,
                r22_realtime: false,
            },
        }
    }
}

#[cfg(test)]
mod capabilities_tests {
    use super::*;

    #[test]
    fn whoop4_capabilities() {
        let caps = DeviceCapabilities::for_kind(DeviceKind::Whoop4);
        assert_eq!(caps.wire_protocol, "gen4");
        assert_eq!(caps.historical_sync, "page_sequence");
        assert!(!caps.battery_via_r22);
        assert!(caps.battery_via_event48);
        assert!(caps.battery_via_cmd26);
        assert!(!caps.r22_realtime);
    }

    #[test]
    fn whoop5_capabilities() {
        let caps = DeviceCapabilities::for_kind(DeviceKind::Whoop5);
        assert_eq!(caps.wire_protocol, "gen5");
        assert_eq!(caps.historical_sync, "stream");
        assert!(caps.battery_via_r22);
        assert!(caps.battery_via_event48);
        assert!(caps.battery_via_cmd26);
        assert!(caps.r22_realtime);
    }

    #[test]
    fn hr_monitor_capabilities() {
        let caps = DeviceCapabilities::for_kind(DeviceKind::HrMonitor);
        assert_eq!(caps.wire_protocol, "gen5");
        assert_eq!(caps.historical_sync, "stream");
        assert!(!caps.battery_via_r22);
        assert!(!caps.battery_via_event48);
        assert!(!caps.battery_via_cmd26);
        assert!(!caps.r22_realtime);
    }

    #[test]
    fn device_kind_screaming_snake_case_serde() {
        // DeviceKind serialises/deserialises with SCREAMING_SNAKE_CASE
        let json = serde_json::to_string(&DeviceKind::Whoop4).unwrap();
        assert_eq!(json, r#""WHOOP4""#);
        let json = serde_json::to_string(&DeviceKind::Whoop5).unwrap();
        assert_eq!(json, r#""WHOOP5""#);
        let json = serde_json::to_string(&DeviceKind::HrMonitor).unwrap();
        assert_eq!(json, r#""HR_MONITOR""#);
    }

    #[test]
    fn device_kind_deserialise_from_screaming_snake_case() {
        let kind: DeviceKind = serde_json::from_str(r#""WHOOP4""#).unwrap();
        assert_eq!(kind, DeviceKind::Whoop4);
        let kind: DeviceKind = serde_json::from_str(r#""WHOOP5""#).unwrap();
        assert_eq!(kind, DeviceKind::Whoop5);
        let kind: DeviceKind = serde_json::from_str(r#""HR_MONITOR""#).unwrap();
        assert_eq!(kind, DeviceKind::HrMonitor);
    }

    #[test]
    fn device_kind_unknown_variant_rejected() {
        let result: Result<DeviceKind, _> = serde_json::from_str(r#""UNKNOWN""#);
        assert!(result.is_err(), "unknown DeviceKind should be rejected");
    }

    #[test]
    fn device_capabilities_serde_roundtrip() {
        let caps = DeviceCapabilities::for_kind(DeviceKind::Whoop5);
        let json = serde_json::to_string(&caps).unwrap();
        let decoded: DeviceCapabilities = serde_json::from_str(&json).unwrap();
        assert_eq!(caps, decoded);
    }
}
