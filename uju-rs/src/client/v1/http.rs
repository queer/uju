use std::time::Duration;

use crate::client::v1::UjuV1Errors;
use crate::protocol::v1::*;

use miette::{IntoDiagnostic, Result};

pub struct UjuHttp {
    url: String,
    compression: Compression,
    format: Format,
    client: reqwest::Client,
    session: Option<String>,
    heartbeat_interval: Option<Duration>,
}

impl UjuHttp {
    pub fn new(url: String) -> Self {
        Self::new_with_opts(url, Compression::None, Format::Json)
    }

    pub fn new_with_opts(url: String, compression: Compression, format: Format) -> Self {
        Self {
            url,
            compression,
            format,
            client: reqwest::Client::new(),
            session: None,
            heartbeat_interval: None,
        }
    }

    pub async fn start_session(&mut self) -> Result<()> {
        let response = self
            .client
            .post(routes::build_route(&self.url, routes::START_SESSION))
            .body(
                serde_json::to_string(&SessionConfig {
                    format: self.format,
                    compression: self.compression,
                    metadata: None,
                })
                .into_diagnostic()?,
            )
            .send()
            .await
            .into_diagnostic()?;

        let payload: Payload = response.text().await.into_diagnostic()?.into();

        debug_assert!(std::matches!(
            payload,
            Payload::ServerMessage {
                code: ResponseCodes::ResponseStatusSuccess,
                ..
            }
        ));

        let response = self.fetch_messages().await?;

        debug_assert!(response.len() == 1);

        debug_assert!(matches!(response[0], Payload::Hello { .. }));

        if let Payload::Hello { session, heartbeat } = response[0].clone() {
            self.session = Some(session);
            self.heartbeat_interval = Some(Duration::from_millis(heartbeat));
        } else {
            unreachable!(
                "the server should ALWAYS return a Hello payload here, got: {:?}",
                response[0]
            );
        }

        Ok(())
    }

    pub async fn authenticate(&self) -> Result<()> {
        let response = self
            .client
            .post(routes::build_route(&self.url, routes::SEND))
            .header(
                "Authorization",
                format!("Session {}", self.session.as_ref().unwrap()),
            )
            .body(
                serde_json::to_string(&Payload::Authenticate {
                    auth: "a".into(),
                    config: SessionConfig {
                        format: self.format,
                        compression: self.compression,
                        metadata: None,
                    },
                })
                .into_diagnostic()?,
            )
            .send()
            .await
            .into_diagnostic()?;

        let payload: Payload = response.text().await.into_diagnostic()?.into();

        debug_assert!(std::matches!(
            payload,
            Payload::ServerMessage {
                code: ResponseCodes::ResponseStatusSuccess,
                ..
            }
        ));

        let messages = self.fetch_messages().await?;

        debug_assert!(messages.len() == 1);

        debug_assert!(matches!(messages[0], Payload::ServerMessage { .. }));

        if let Payload::ServerMessage {
            code: ResponseCodes::AuthSuccess,
            ..
        } = messages[0].clone()
        {
            Ok(())
        } else if let Payload::ServerMessage {
            code: ResponseCodes::AuthFailure,
            ..
        } = messages[0].clone()
        {
            Err(UjuV1Errors::AuthFailure.into())
        } else {
            unreachable!(
                "the server should ALWAYS return a ServerMessage payload here, got: {:?}",
                messages[0]
            );
        }
    }

    pub async fn fetch_messages(&self) -> Result<Vec<Payload>> {
        let response = self
            .client
            .get(routes::build_route(&self.url, routes::FLUSH_MAILBOX))
            .header(
                "Authorization",
                format!(
                    "Session {}",
                    self.session.as_ref().expect("no session id!?")
                ),
            )
            .send()
            .await
            .into_diagnostic()?;

        let payload: Payload = response.text().await.into_diagnostic()?.into();
        // TODO: Ewwwww
        if let Payload::ServerMessage { ref extra, .. } = payload {
            if let Some(extra) = extra {
                if extra.is_array() {
                    let messages: Vec<Payload> = extra
                        .as_array()
                        .unwrap()
                        .iter()
                        .map(|v| serde_json::from_value(v.clone()).into_diagnostic().unwrap())
                        .collect();
                    Ok(messages)
                } else {
                    unreachable!("the server should ALWAYS return a ServerMessage payload with an extra field that is an array here, got: {:?}", &payload)
                }
            } else {
                unreachable!("the server should ALWAYS return a ServerMessage payload with an extra field here, got: {:?}", payload)
            }
        } else {
            unreachable!(
                "the server should NEVER return a non-ServerMessage payload here, got: {:?}",
                payload
            )
        }
    }
}
