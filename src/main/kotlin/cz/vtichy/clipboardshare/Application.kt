package cz.vtichy.clipboardshare

import io.ktor.application.*
import io.ktor.features.*
import io.ktor.http.*
import io.ktor.request.*
import io.ktor.response.*
import io.ktor.routing.*
import io.ktor.serialization.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import kotlinx.serialization.Serializable
import org.slf4j.event.Level

private val verificationToken: String = System.getenv("VERIFICATION_TOKEN") ?: "test"
private var content: String = ""

fun main() {
    embeddedServer(Netty, port = 9876, host = "0.0.0.0") {
        install(CallLogging) {
            level = Level.INFO
            format { call ->
                val httpMethod = call.request.httpMethod.value
                val path = call.request.path()
                val status = call.response.status()?.value
                val remoteHost = call.request.origin.remoteHost
                val userAgent = call.request.headers["User-Agent"]
                "$httpMethod $path $status ($remoteHost, $userAgent)"
            }
        }

        install(ContentNegotiation) {
            json()
        }

        routing {
            get("/") {
                if (!validate(call)) {
                    return@get
                }

                call.respond(ContentWrapper(content))
            }
            post("/") {
                if (!validate(call)) {
                    return@post
                }

                content = call.receive<ContentWrapper>().content
                call.respond(HttpStatusCode.Accepted, "")
            }
        }
    }.start(wait = true)
}

suspend fun validate(call: ApplicationCall): Boolean {
    return if (call.request.header("Verification-Token") != verificationToken) {
        call.respond(HttpStatusCode.Unauthorized, "Invalid verification token")
        false
    } else {
        true
    }
}

@Serializable
data class ContentWrapper(val content: String)