// RUN WITH DENO

const AUTH_SUCCESS = 0
const AUTH_FAIL = 1
const CONFIGURE_SUCCESS = 2
const PARSE_FAIL = 3
const INVALID_CLIENT_PAYLOAD = 4

enum ClientState {
  STARTED,
  AUTHENTICATING,
  READY
}

class UjuMiniClient {
  #session: string | null = null
  #ws: WebSocket
  #heartbeatInterval: number = 5_000
  #state: ClientState = ClientState.STARTED
  #heartbeatTimer: number | null = null

  constructor() {
    this.#ws = new WebSocket("ws://localhost:8080/api/v1/socket")
    this.#ws.onopen = () => {
      console.log("connected to uju server")
    }
    this.#ws.onclose = () => {
      console.log("disconnected from uju server")
    }
    this.#ws.onmessage = (e) => {
      this.handleMessage(JSON.parse(e.data))
    }
    this.#ws.onerror = (e) => {
      console.error("UNEXPECTED ERROR:", e)
    }
  }

  send(data: any) {
    this.#ws.send(JSON.stringify(data))
  }

  close() {
    if(this.#heartbeatTimer) {
      clearInterval(this.#heartbeatTimer)
    }
    this.#ws.close()
  }

  handleMessage(data: any) {
    // console.debug(data)
    const { opcode, payload } = data
    switch(opcode) {
      case "HELLO": {
        this.#session = payload.session
        this.#heartbeatInterval = payload.heartbeat
        this.#state = ClientState.AUTHENTICATING
        console.log("started new session!")
        this.#heartbeatTimer = setInterval(() => {
          this.send({
            opcode: "PING",
            payload: {
              nonce: "42069"
            }
          })
        }, this.#heartbeatInterval)
        this._authenticate()
        break
      }
      case "SERVER_MESSAGE": {
        switch(payload.code) {
          case AUTH_SUCCESS: {
            this.#state = ClientState.READY
            console.log("authenticated")
            this._configure()
            break
          }
          case AUTH_FAIL: {
            console.error("authentication failed")
            this.close()
            break
          }
          case CONFIGURE_SUCCESS: {
            console.log("configured")
            this.send({
              opcode: "SEND",
              payload: {
                method: "immediate",
                data: "test",
                query: {
                  _debug: {},
                  filter: [],
                  select: null,
                },
                config: {
                  nonce: "asdf",
                  await_reply: false,
                }
              }
            })
            break
          }
          default: {
            console.error("UNKNOWN SERVER MESSAGE CODE:", payload.code)
            break
          }
        }
        break
      }
      case "RECEIVE": {
        console.log("received:", payload.data)
        if(payload.data === "test that should always be seen") {
          console.log("looks good, waiting for heartbeat to close")
          setTimeout(() => this.close(), 10_000)
          break
        }
        this.send({
          opcode: "SEND",
          payload: {
            method: "immediate",
            data: "test that should never be seen",
            query: {
              _debug: {},
              filter: [{
                path: "/key",
                op: "$lt",
                value: { value: 69 }
              }],
              select: null,
            },
            config: {
              nonce: "asdf",
              await_reply: false,
            }
          }
        })
        this.send({
          opcode: "SEND",
          payload: {
            method: "immediate",
            data: "test that should always be seen",
            query: {
              _debug: {},
              filter: [{
                path: "/key",
                op: "$gt",
                value: { value: 69 }
              }],
              select: null,
            },
            config: {
              nonce: "asdf",
              await_reply: false,
            }
          }
        })
        break
      }
      case "PONG": {
        console.log("heartbeat worked!")
        break
      }
      default: {
        console.error("UNKNOWN OPCODE:", opcode)
      }
    }
  }

  _authenticate() {
    if(!this.#session) {
      throw new Error("not authenticated")
    }
    this.send({
      opcode: "AUTHENTICATE",
      payload: {
        auth: "123",
        config: {
          format: "json",
          compression: "none",
          metadata: {}
        },
      },
    })
  }

  _configure() {
    this.send({
      opcode: "CONFIGURE",
      payload: {
        scope: "session",
        config: {
          format: "json",
          compression: "none",
          metadata: {
            "key": 123
          }
        }
      }
    })
  }
}

const _client = new UjuMiniClient()