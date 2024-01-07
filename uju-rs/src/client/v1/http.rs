use crate::protocol::v1::*;

use miette::Result;

pub struct UjuHttp {
    url: String,
    compression: Compression,
    format: Format,
    client: reqwest::Client,
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
                .unwrap(), // TODO
            )
            .send()
            .await
            .unwrap(); // TODO

        let _payload: Payload = response.text().await.unwrap().into();

        // debug_assert_eq!(payload.opcode, Opcode::Hello);

        Ok(())
    }
}
