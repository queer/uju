use miette::Diagnostic;
use thiserror::Error;

pub mod http;
pub mod websocket;

#[derive(Error, Diagnostic, Debug)]
pub enum UjuV1Errors {}
