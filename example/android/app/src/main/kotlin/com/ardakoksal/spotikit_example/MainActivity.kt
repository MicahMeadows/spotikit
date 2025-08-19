package com.ardakoksal.spotikit_example

import android.content.Intent
import android.util.Base64
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.lifecycleScope
import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.sdk.android.auth.AuthorizationClient
import com.spotify.sdk.android.auth.AuthorizationRequest
import com.spotify.sdk.android.auth.AuthorizationResponse
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class MainActivity: FlutterActivity() {

    companion object {
        private const val CHANNEL_NAME = "spotikit/spotify"
        private const val REQUEST_CODE = 1337
        private const val TAG = "SpotikitMainActivity"

        // Token refresh margin (refresh 5 minutes before expiry)
        private const val TOKEN_REFRESH_MARGIN_MS = 5 * 60 * 1000L
    }

    // Configuration properties (set from Flutter)
    private var clientId: String? = null
    private var clientSecret: String? = null
    private var redirectUri: String? = null
    private var spotifyScope: String? = null

    // Class properties
    private var spotifyAppRemote: SpotifyAppRemote? = null
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    private lateinit var channel: MethodChannel

    // In-memory token cache
    private var accessToken: String? = null
    private var refreshToken: String? = null
    private var tokenExpiresAt: Long = 0

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializeSpotify" -> initializeSpotify(call, result)
                "connectToSpotify" -> connectToSpotify(result)
                "authenticateSpotify" -> authenticateSpotify(result)
                "getAccessToken" -> getAccessToken(result)
                "refreshToken" -> refreshToken(result)
                "isTokenValid" -> isTokenValid(result)
                "play" -> {
                    val spotifyUri: String? = call.argument("spotifyUri")
                    if (spotifyUri != null) play(spotifyUri, result)
                    else result.error("INVALID_ARGUMENT", "spotifyUri cannot be null", null)
                }
                "pause" -> pause(result)
                "resume" -> resume(result)
                "disconnect" -> disconnect(result)
                "getTrackInfo" -> getTrackInfo(result)
                "getPlayerState" -> getPlayerState(result)
                "logout" -> logout(result)
                "skipTrack" -> skipTrack(result)
                "previousTrack" -> previousTrack(result)
                "setVolume" -> {
                    val volume: Double? = call.argument("volume")
                    if (volume != null) setVolume(volume.toFloat(), result)
                    else result.error("INVALID_ARGUMENT", "volume cannot be null", null)
                }
                "seekTo" -> {
                    val positionMs: Long? = call.argument("positionMs")
                    if (positionMs != null) seekTo(positionMs, result)
                    else result.error("INVALID_ARGUMENT", "positionMs cannot be null", null)
                }
                "isConnected" -> isConnected(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun initializeSpotify(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        try {
            clientId = call.argument<String>("clientId")
            clientSecret = call.argument<String>("clientSecret")
            redirectUri = call.argument<String>("redirectUri")
            spotifyScope = call.argument<String>("scope")

            if (clientId.isNullOrEmpty() || clientSecret.isNullOrEmpty() ||
                redirectUri.isNullOrEmpty() || spotifyScope.isNullOrEmpty()) {
                result.error("INVALID_CONFIG", "All configuration parameters are required", mapOf(
                    "requiredParams" to listOf("clientId", "clientSecret", "redirectUri", "scope")
                ))
                return
            }

            Log.d(TAG, "✅ Spotify configuration initialized")
            result.success(mapOf(
                "status" to "initialized",
                "clientId" to clientId,
                "redirectUri" to redirectUri
            ))

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing Spotify configuration", e)
            result.error("INIT_ERROR", "Failed to initialize Spotify configuration", mapOf(
                "message" to (e.message ?: "Unknown error")
            ))
        }
    }

    private fun requireConfiguration(): Boolean {
        return !clientId.isNullOrEmpty() &&
               !clientSecret.isNullOrEmpty() &&
               !redirectUri.isNullOrEmpty() &&
               !spotifyScope.isNullOrEmpty()
    }

    private fun connectToSpotify(result: MethodChannel.Result) {
        if (!requireConfiguration()) {
            result.error("NOT_INITIALIZED", "Spotify configuration not initialized. Call initializeSpotify first.", null)
            return
        }

        if (spotifyAppRemote?.isConnected == true) {
            result.success(mapOf("status" to "already_connected"))
            return
        }

        val connectionParams = ConnectionParams.Builder(clientId!!)
            .setRedirectUri(redirectUri!!)
            .showAuthView(true)
            .build()

        val connectionListener = object : Connector.ConnectionListener {
            override fun onConnected(appRemote: SpotifyAppRemote) {
                spotifyAppRemote = appRemote
                Log.d(TAG, "✅ Spotify Connected!")
                result.success(mapOf("status" to "connected"))
            }

            override fun onFailure(throwable: Throwable) {
                Log.e(TAG, "❌ Spotify connection failed: ${throwable.message}", throwable)

                val errorMap = mutableMapOf<String, Any>(
                    "status" to "failed",
                    "message" to (throwable.message ?: "Unknown error")
                )

                when (throwable) {
                    is com.spotify.android.appremote.api.error.NotLoggedInException -> {
                        errorMap["type"] = "not_logged_in"
                        result.error("NOT_LOGGED_IN", "User not logged in", errorMap)
                    }
                    is com.spotify.android.appremote.api.error.UserNotAuthorizedException -> {
                        errorMap["type"] = "not_authorized"
                        result.error("NOT_AUTHORIZED", "User not authorized", errorMap)
                    }
                    else -> {
                        errorMap["type"] = "connection_error"
                        result.error("CONNECTION_ERROR", "Could not connect to Spotify", errorMap)
                    }
                }
            }
        }

        SpotifyAppRemote.connect(this, connectionParams, connectionListener)
    }

    private fun authenticateSpotify(result: MethodChannel.Result) {
        if (!requireConfiguration()) {
            result.error("NOT_INITIALIZED", "Spotify configuration not initialized. Call initializeSpotify first.", null)
            return
        }

        Log.d(TAG, "🔐 Starting Spotify authentication flow...")

        val builder = AuthorizationRequest.Builder(clientId!!, AuthorizationResponse.Type.CODE, redirectUri!!)
        builder.setScopes(spotifyScope!!.split(" ").toTypedArray())

        val request = builder.build()
        AuthorizationClient.openLoginActivity(this, REQUEST_CODE, request)

        result.success(mapOf("status" to "authentication_started"))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?) {
        super.onActivityResult(requestCode, resultCode, intent)

        if (requestCode == REQUEST_CODE) {
            val response = AuthorizationClient.getResponse(resultCode, intent)

            when (response.type) {
                AuthorizationResponse.Type.CODE -> {
                    Log.d(TAG, "✅ Authorization code received")
                    exchangeCodeForTokens(response.code)
                }
                AuthorizationResponse.Type.ERROR -> {
                    Log.e(TAG, "❌ Auth error: ${response.error}")
                    channel.invokeMethod("spotifyAuthFailed", mapOf(
                        "error" to response.error,
                        "message" to "Authentication failed"
                    ))
                }
                else -> {
                    Log.d(TAG, "🚫 Auth result: ${response.type}")
                    channel.invokeMethod("spotifyAuthCancelled", mapOf(
                        "message" to "Authentication cancelled by user"
                    ))
                }
            }
        }
    }

    private fun exchangeCodeForTokens(code: String) {
        if (!requireConfiguration()) {
            channel.invokeMethod("spotifyAuthFailed", mapOf(
                "error" to "not_initialized",
                "message" to "Spotify configuration not initialized"
            ))
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val credentials = "$clientId:$clientSecret"
                val encodedCredentials = Base64.encodeToString(credentials.toByteArray(), Base64.NO_WRAP)

                val formBody = FormBody.Builder()
                    .add("grant_type", "authorization_code")
                    .add("code", code)
                    .add("redirect_uri", redirectUri!!)
                    .build()

                val request = Request.Builder()
                    .url("https://accounts.spotify.com/api/token")
                    .addHeader("Authorization", "Basic $encodedCredentials")
                    .addHeader("Content-Type", "application/x-www-form-urlencoded")
                    .post(formBody)
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    val responseBody = response.body?.string()

                    if (!response.isSuccessful || responseBody == null) {
                        Log.e(TAG, "❌ Failed to exchange code for tokens: ${response.message}")
                        withContext(Dispatchers.Main) {
                            channel.invokeMethod("spotifyAuthFailed", mapOf(
                                "error" to "token_exchange_failed",
                                "message" to (responseBody ?: "Unknown error"),
                                "statusCode" to response.code
                            ))
                        }
                        return@launch
                    }

                    val jsonObject = JSONObject(responseBody)
                    accessToken = jsonObject.getString("access_token")
                    refreshToken = jsonObject.optString("refresh_token", refreshToken)
                    val expiresIn = jsonObject.getInt("expires_in")
                    tokenExpiresAt = System.currentTimeMillis() + (expiresIn * 1000L)

                    Log.d(TAG, "✅ Successfully obtained tokens")

                    withContext(Dispatchers.Main) {
                        channel.invokeMethod("spotifyAuthSuccess", mapOf(
                            "accessToken" to accessToken,
                            "expiresAt" to tokenExpiresAt,
                            "hasRefreshToken" to (refreshToken != null)
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error exchanging code for tokens", e)
                withContext(Dispatchers.Main) {
                    channel.invokeMethod("spotifyAuthFailed", mapOf(
                        "error" to "exception",
                        "message" to (e.message ?: "Unknown exception")
                    ))
                }
            }
        }
    }

    private fun getAccessToken(result: MethodChannel.Result) {
        val currentTime = System.currentTimeMillis()

        if (accessToken != null && currentTime < (tokenExpiresAt - TOKEN_REFRESH_MARGIN_MS)) {
            result.success(mapOf(
                "token" to accessToken,
                "expiresAt" to tokenExpiresAt,
                "isValid" to true
            ))
        } else if (refreshToken != null) {
            Log.d(TAG, "🔄 Access token expired or about to expire, refreshing...")
            refreshToken(result)
        } else {
            result.error("NO_TOKEN", "No valid token available. Please authenticate.", mapOf(
                "requiresAuth" to true
            ))
        }
    }

    private fun refreshToken(result: MethodChannel.Result) {
        if (!requireConfiguration()) {
            result.error("NOT_INITIALIZED", "Spotify configuration not initialized", null)
            return
        }

        val currentRefreshToken = refreshToken
        if (currentRefreshToken == null) {
            result.error("NO_REFRESH_TOKEN", "No refresh token available", mapOf(
                "requiresAuth" to true
            ))
            return
        }

        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val credentials = "$clientId:$clientSecret"
                val encodedCredentials = Base64.encodeToString(credentials.toByteArray(), Base64.NO_WRAP)

                val formBody = FormBody.Builder()
                    .add("grant_type", "refresh_token")
                    .add("refresh_token", currentRefreshToken)
                    .build()

                val request = Request.Builder()
                    .url("https://accounts.spotify.com/api/token")
                    .addHeader("Authorization", "Basic $encodedCredentials")
                    .post(formBody)
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    val responseBody = response.body?.string()

                    if (!response.isSuccessful || responseBody == null) {
                        Log.e(TAG, "❌ Failed to refresh token: ${response.message}")
                        withContext(Dispatchers.Main) {
                            result.error("REFRESH_ERROR", "Failed to refresh token", mapOf(
                                "statusCode" to response.code,
                                "message" to (responseBody ?: "Unknown error"),
                                "requiresAuth" to (response.code == 400 || response.code == 401)
                            ))
                        }
                        return@launch
                    }

                    val jsonObject = JSONObject(responseBody)
                    accessToken = jsonObject.getString("access_token")
                    refreshToken = jsonObject.optString("refresh_token", currentRefreshToken)
                    val expiresIn = jsonObject.getInt("expires_in")
                    tokenExpiresAt = System.currentTimeMillis() + (expiresIn * 1000L)

                    Log.d(TAG, "✅ Successfully refreshed token")

                    withContext(Dispatchers.Main) {
                        result.success(mapOf(
                            "token" to accessToken,
                            "expiresAt" to tokenExpiresAt,
                            "isValid" to true
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error refreshing token", e)
                withContext(Dispatchers.Main) {
                    result.error("REFRESH_EXCEPTION", "Exception while refreshing token", mapOf(
                        "message" to (e.message ?: "Unknown exception"),
                        "requiresAuth" to true
                    ))
                }
            }
        }
    }

    private fun isTokenValid(result: MethodChannel.Result) {
        val currentTime = System.currentTimeMillis()
        val isValid = accessToken != null && currentTime < (tokenExpiresAt - TOKEN_REFRESH_MARGIN_MS)

        result.success(mapOf(
            "isValid" to isValid,
            "expiresAt" to tokenExpiresAt,
            "hasRefreshToken" to (refreshToken != null)
        ))
    }

    private fun logout(result: MethodChannel.Result) {
        disconnect(object : MethodChannel.Result {
            override fun success(res: Any?) {
                // Clear in-memory tokens
                accessToken = null
                refreshToken = null
                tokenExpiresAt = 0
                Log.d(TAG, "🚪 User logged out and tokens cleared from memory")
                result.success(mapOf("status" to "logged_out"))
            }
            override fun error(code: String, msg: String?, details: Any?) {
                result.error(code, msg, details)
            }
            override fun notImplemented() {
                result.notImplemented()
            }
        })
    }

    // Helper function for connection-dependent operations
    private fun performActionIfConnected(result: MethodChannel.Result, action: (SpotifyAppRemote) -> Unit) {
        val remote = spotifyAppRemote
        if (remote != null && remote.isConnected) {
            action(remote)
        } else {
            result.error("NOT_CONNECTED", "Spotify App Remote is not connected", mapOf(
                "requiresConnection" to true
            ))
        }
    }

    private fun isConnected(result: MethodChannel.Result) {
        val isConnected = spotifyAppRemote?.isConnected == true
        result.success(mapOf(
            "isConnected" to isConnected
        ))
    }

    private fun play(spotifyUri: String, result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.play(spotifyUri)
                .setResultCallback {
                    result.success(mapOf(
                        "status" to "playing",
                        "uri" to spotifyUri
                    ))
                }
                .setErrorCallback { throwable ->
                    result.error("PLAY_ERROR", "Failed to play URI", mapOf(
                        "uri" to spotifyUri,
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun pause(result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.pause()
                .setResultCallback {
                    result.success(mapOf("status" to "paused"))
                }
                .setErrorCallback { throwable ->
                    result.error("PAUSE_ERROR", "Failed to pause", mapOf(
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun resume(result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.resume()
                .setResultCallback {
                    result.success(mapOf("status" to "resumed"))
                }
                .setErrorCallback { throwable ->
                    result.error("RESUME_ERROR", "Failed to resume", mapOf(
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun getTrackInfo(result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.playerState
                .setResultCallback { playerState ->
                    val trackInfo = mapOf(
                        "artist" to playerState.track.artist.name,
                        "name" to playerState.track.name,
                        "uri" to playerState.track.uri,
                        "isPaused" to playerState.isPaused,
                        "album" to (playerState.track.album?.name ?: ""),
                        "imageUri" to (playerState.track.imageUri?.raw ?: ""),
                        "duration" to playerState.track.duration,
                        "playbackPosition" to playerState.playbackPosition
                    )
                    result.success(trackInfo)
                }
                .setErrorCallback { throwable ->
                    result.error("TRACK_INFO_ERROR", "Failed to get track info", mapOf(
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun getPlayerState(result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.playerState
                .setResultCallback { playerState ->
                    val state = mapOf(
                        "track" to mapOf(
                            "artist" to playerState.track.artist.name,
                            "name" to playerState.track.name,
                            "uri" to playerState.track.uri,
                            "album" to (playerState.track.album?.name ?: ""),
                            "imageUri" to (playerState.track.imageUri?.raw ?: ""),
                            "duration" to playerState.track.duration
                        ),
                        "isPaused" to playerState.isPaused,
                        "playbackSpeed" to playerState.playbackSpeed,
                        "playbackPosition" to playerState.playbackPosition,
                        "playbackOptions" to mapOf(
                            "isShuffling" to playerState.playbackOptions.isShuffling,
                            "repeatMode" to playerState.playbackOptions.repeatMode.ordinal
                        ),
                        "playbackRestrictions" to mapOf(
                            "canSkipNext" to playerState.playbackRestrictions.canSkipNext,
                            "canSkipPrev" to playerState.playbackRestrictions.canSkipPrev,
                            "canRepeatTrack" to playerState.playbackRestrictions.canRepeatTrack,
                            "canRepeatContext" to playerState.playbackRestrictions.canRepeatContext,
                            "canToggleShuffle" to playerState.playbackRestrictions.canToggleShuffle,
                            "canSeek" to playerState.playbackRestrictions.canSeek
                        )
                    )
                    result.success(state)
                }
                .setErrorCallback { throwable ->
                    result.error("PLAYER_STATE_ERROR", "Failed to get player state", mapOf(
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun skipTrack(result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.skipNext()
                .setResultCallback {
                    result.success(mapOf("status" to "skipped_next"))
                }
                .setErrorCallback { throwable ->
                    result.error("SKIP_ERROR", "Failed to skip track", mapOf(
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun previousTrack(result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.skipPrevious()
                .setResultCallback {
                    result.success(mapOf("status" to "skipped_previous"))
                }
                .setErrorCallback { throwable ->
                    result.error("PREVIOUS_ERROR", "Failed to skip to previous track", mapOf(
                        "message" to (throwable.message ?: "Unknown error")
                    ))
                }
        }
    }

    private fun setVolume(volume: Float, result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            // Clamp volume between 0.0 and 1.0
            val clampedVolume = volume.coerceIn(0.0f, 1.0f)

            remote.playerApi.setVolume(clampedVolume)
                .setResultCallback {
                    result.success(mapOf(
                        "status" to "volume_set",
                        "volume" to clampedVolume
                    ))
                }
                .setErrorCallback { throwable ->
                    result.error("VOLUME_ERROR", "Failed to set volume", mapOf(
                        "message" to (throwable.message ?: "Unknown error"),
                        "requestedVolume" to clampedVolume
                    ))
                }
        }
    }

    private fun seekTo(positionMs: Long, result: MethodChannel.Result) {
        performActionIfConnected(result) { remote ->
            remote.playerApi.seekTo(positionMs)
                .setResultCallback {
                    result.success(mapOf(
                        "status" to "seeked",
                        "position" to positionMs
                    ))
                }
                .setErrorCallback { throwable ->
                    result.error("SEEK_ERROR", "Failed to seek", mapOf(
                        "message" to (throwable.message ?: "Unknown error"),
                        "requestedPosition" to positionMs
                    ))
                }
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        spotifyAppRemote?.let { remote ->
            if (remote.isConnected) {
                SpotifyAppRemote.disconnect(remote)
                spotifyAppRemote = null
                Log.d(TAG, "🔌 Spotify Disconnected!")
                result.success(mapOf("status" to "disconnected"))
            } else {
                result.success(mapOf("status" to "already_disconnected"))
            }
        } ?: result.success(mapOf("status" to "not_connected"))
    }

    override fun onStop() {
        super.onStop()
        // Disconnect when app goes to background to free resources
        spotifyAppRemote?.let { remote ->
            if (remote.isConnected) {
                SpotifyAppRemote.disconnect(remote)
                spotifyAppRemote = null
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up HTTP client
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
    }
}