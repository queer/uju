use either::Either;
use miette::IntoDiagnostic;
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};

pub mod routes {
    pub const ROOT: &str = "/api/v1";
    pub const START_SESSION: &str = "/start-session";
    pub const SEND: &str = "/send";
    pub const FLUSH_MAILBOX: &str = "/flush-mailbox";
    pub const WEBSOCKET: &str = "/socket";

    pub fn build_route(host: &str, route: &str) -> String {
        format!("{}{}{}", host, ROOT, route)
    }
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
#[serde(
    rename_all = "SCREAMING_SNAKE_CASE",
    tag = "opcode",
    content = "payload"
)]
pub enum Payload {
    Hello {
        session: String,
        heartbeat: u64,
    },
    Authenticate {
        auth: String,
        config: SessionConfig,
    },
    ServerMessage {
        code: ResponseCodes,
        message: String,
        /// TODO: can be any...
        extra: Option<serde_json::Value>,
        layer: String,
    },
    Send {
        method: SendMethod,
        // TODO: Can be any
        data: String,
        #[serde(with = "either::serde_untagged")]
        config: Either<SendConfig, SendLaterConfig>,
        // TODO: Can be any
        query: MetadataQuery<String>,
    },
    Receive {
        nonce: Option<String>,
        // TODO: Can be any
        data: String,
    },
    Ping {
        nonce: String,
    },
    Pong {
        nonce: String,
    },
    Configure {
        scope: ConfigureScope,
        config: ConfigurePayload,
    },
}

impl From<String> for Payload {
    fn from(val: String) -> Self {
        serde_json::from_str(&val).into_diagnostic().unwrap()
    }
}

#[derive(Serialize_repr, Deserialize_repr, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
#[repr(i32)]
pub enum ResponseCodes {
    ResponseStatusFailure = -2,
    ResponseStatusSuccess = -1,
    AuthSuccess = 0,
    AuthFailure = 1,
    ConfigureSuccess = 2,
    ParseFailure = 3,
    InvalidClientPayload = 4,
}

#[derive(Serialize, Deserialize, Clone, Debug, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum Format {
    Json,
    Msgpack,
}

#[derive(Serialize, Deserialize, Clone, Debug, Copy, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum Compression {
    None,
    Zstd,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct SessionConfig {
    pub format: Format,
    pub compression: Compression,
    /// TODO
    pub metadata: Option<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Replication {
    None,
    Datacenter,
    Region,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct GroupConfig {
    pub max_size: u64,
    pub max_age: u64,
    pub replication: Replication,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct GlobalSessionConfig {
    pub max_size: u64,
    pub max_age: u64,
    pub replication: Replication,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct SendConfig {
    pub nonce: String,
    pub await_reply: bool,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct SendLaterConfig {
    pub group: String,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum BooleanOperator {
    Equals,
    NotEquals,
    GreaterThan,
    GreaterThanOrEqual,
    LessThan,
    LessThanOrEqual,
    In,
    NotIn,
    Contains,
    NotContains,
    Exists,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogicalOperator {
    And,
    Or,
    Not,
    Xor,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum MetadataValue {
    Path { path: String },
    Value { value: String },
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct BooleanOperation {
    pub op: BooleanOperator,
    pub path: String,
    pub value: MetadataValue,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct LogicalOperation {
    pub op: LogicalOperator,
    pub operands: Vec<Either<BooleanOperation, LogicalOperation>>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Ordering {
    Ascending,
    Descending,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Selector {
    pub limit: Option<u64>,
    pub ordering: Option<Vec<(Ordering, String)>>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct MetadataSelect {
    pub ordering: Vec<(Ordering, String)>,
    pub limit: u64,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct MetadataQuery<D: Serialize> {
    #[serde(rename = "_debug")]
    pub debug: D,
    pub filter: Vec<Either<BooleanOperation, LogicalOperation>>,
    pub select: Option<MetadataSelect>,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum SendMethod {
    Immediate,
    Later,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
#[serde(rename_all = "lowercase")]
pub enum ConfigureScope {
    Session,
    Group,
    Global,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
#[serde(untagged)]
pub enum ConfigurePayload {
    Session(SessionConfig),
    Group(GroupConfig),
    Global(GlobalSessionConfig),
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_payload;

    use miette::Result;

    #[test]
    fn test_hello_payload() -> Result<()> {
        test_payload!(
            Payload::Hello {
                session: "test".into(),
                heartbeat: 1000,
            },
            r#"
        {
            "opcode": "HELLO",
            "payload": {
                "session": "test",
                "heartbeat": 1000
            }
        }
        "#
        );
    }

    #[test]
    fn test_server_message_payload() -> Result<()> {
        test_payload!(
            Payload::ServerMessage {
                code: ResponseCodes::ResponseStatusSuccess,
                message: "success".into(),
                extra: Some("ok".into()),
                layer: "protocol".into(),
            },
            r#"
        {
            "opcode": "SERVER_MESSAGE",
            "payload": {
                "code": -1,
                "extra": "ok",
                "layer": "protocol",
                "message": "success"
            }
        }"#
        );
    }

    #[test]
    fn test_authenticate_payload() -> Result<()> {
        test_payload!(
            Payload::Authenticate {
                auth: "a".into(),
                config: SessionConfig {
                    format: Format::Json,
                    compression: Compression::None,
                    metadata: None,
                },
            },
            r#"
        {
            "opcode": "AUTHENTICATE",
            "payload": {
                "auth": "a",
                "config": {
                    "compression": "none",
                    "format": "json"
                }
            }
        }
        "#
        );
    }

    #[test]
    fn test_server_message_auth_success_payload() -> Result<()> {
        test_payload!(
            Payload::ServerMessage {
                code: ResponseCodes::AuthSuccess,
                message: "auth success".into(),
                extra: None,
                layer: "protocol".into(),
            },
            r#"
        {
            "opcode": "SERVER_MESSAGE",
            "payload": {
                "code": 0,
                "layer": "protocol",
                "message": "auth success"
            }
        }"#
        );
    }

    #[test]
    fn test_send_payload() -> Result<()> {
        test_payload!(
            Payload::Send {
                method: SendMethod::Immediate,
                data: "asdf".into(),
                config: Either::Left(SendConfig {
                    nonce: "asdf".into(),
                    await_reply: true,
                }),
                query: MetadataQuery {
                    debug: "asdf".into(),
                    filter: vec![],
                    select: None
                }
            },
            r#"
            {
                "opcode": "SEND",
                "payload": {
                    "method": "immediate",
                    "data": "asdf",
                    "query": {
                        "_debug": "asdf",
                        "filter": [],
                        "select": null
                    },
                    "config": {
                        "nonce": "asdf",
                        "await_reply": true
                    }
                }
            }
            "#
        );
    }

    #[test]
    fn test_receive_payload() -> Result<()> {
        test_payload!(
            Payload::Receive {
                nonce: Some("asdf".into()),
                data: "asdf".into()
            },
            r#"
        {
            "opcode": "RECEIVE",
            "payload": {
                "nonce": "asdf",
                "data": "asdf"
            }
        }
        "#
        );
    }

    #[macro_export]
    macro_rules! test_payload {
        ($opcode:expr, $test:expr) => {
            let expected: Payload = $opcode;

            let actual: Payload = serde_json::from_str($test).into_diagnostic()?;

            assert_eq!(expected, actual);

            return Ok(());
        };
    }
}
