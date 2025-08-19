package com.ardakoksal.spotikit

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Base64
import android.util.Log
import com.spotify.android.appremote.api.ConnectionParams
import com.spotify.android.appremote.api.Connector
import com.spotify.android.appremote.api.SpotifyAppRemote
import com.spotify.sdk.android.auth.AuthorizationClient
import com.spotify.sdk.android.auth.AuthorizationRequest
import com.spotify.sdk.android.auth.AuthorizationResponse
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.*
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

/** SpotikitPlugin */
class SpotikitPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  // Companion object for non-user-specific constants
  companion object {
    private const val CHANNEL_NAME = "spotikit"
    private val TAG = "SpotikitPlugin"
    private const val AUTH_REQUEST_CODE = 1337

    // --- SharedPreferences Keys ---
    private const val PREFS_NAME = "SpotifyTokenPrefs"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_TOKEN_EXPIRES_AT = "token_expires_at"
  }

  // --- Runtime Configuration (set by 'initialize' method) ---
  private var clientId: String? = null
  private var redirectUri: String? = null
  private var clientSecret: String? = null
  private var scope: String? = null

  // Plugin components
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private var activityBinding: ActivityPluginBinding? = null

  // Spotify components
  private var spotifyAppRemote: SpotifyAppRemote? = null
  private val httpClient: OkHttpClient by lazy { OkHttpClient() }
  private lateinit var sharedPreferences: SharedPreferences

  // In-memory token cache
  private var accessToken: String? = null
  private var refreshToken: String? = null
  private var tokenExpiresAt: Long = 0

  // Coroutine scope for background tasks
  private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

  // ---------------------------------------------------------------------------------
  // FlutterPlugin Lifecycle & Activity Handling (No changes here)
  // ... (Your existing lifecycle methods are correct)
  // ---------------------------------------------------------------------------------
  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
    channel.setMethodCallHandler(this)
    sharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    loadTokensFromPrefs()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    coroutineScope.cancel()
    disconnect(object : Result {
      override fun success(result: Any?) { Log.d(TAG, "Disconnected on engine detach.") }
      override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
      override fun notImplemented() {}
    })
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityBinding = binding
    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    spotifyAppRemote?.let { if (it.isConnected) SpotifyAppRemote.disconnect(it) }
    activityBinding?.removeActivityResultListener(this)
    activity = null
    activityBinding = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
  override fun onDetachedFromActivityForConfigChanges() { onDetachedFromActivity() }

  override fun onActivityResult(requestCode: Int, resultCode: Int, intent: Intent?): Boolean {
    if (requestCode == AUTH_REQUEST_CODE) {
      val response = AuthorizationClient.getResponse(resultCode, intent)
      when (response.type) {
        AuthorizationResponse.Type.CODE -> {
          Log.d(TAG, "Successfully received Spotify auth code.")
          exchangeCodeForTokens(response.code)
        }
        AuthorizationResponse.Type.ERROR -> {
          Log.e(TAG, "Spotify auth error: ${response.error}")
          channel.invokeMethod("spotifyAuthFailed", mapOf("error" to response.error))
        }
        else -> {
          Log.w(TAG, "Spotify auth flow cancelled by user.")
          channel.invokeMethod("spotifyAuthFailed", mapOf("error" to "cancelled"))
        }
      }
      return true
    }
    return false
  }

  // ---------------------------------------------------------------------------------
  // MethodCallHandler - UPDATED
  // ---------------------------------------------------------------------------------

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "initialize" -> initialize(call, result)
      "connectToSpotify" -> connectToSpotify(result)
      "authenticateSpotify" -> authenticateSpotify(result)
      "getAccessToken" -> getAccessToken(result)
      "refreshToken" -> refreshToken(result)
      "play" -> {
        val spotifyUri = call.argument<String>("spotifyUri")
        if (spotifyUri != null) play(spotifyUri, result)
        else result.error("INVALID_ARGUMENT", "spotifyUri cannot be null", null)
      }
      "pause" -> pause(result)
      "resume" -> resume(result)
      "disconnect" -> disconnect(result)
      "getTrackInfo" -> getTrackInfo(result)
      "logout" -> logout(result)
      "skipTrack" -> skipTrack(result)
      "previousTrack" -> previousTrack(result)
      else -> result.notImplemented()
    }
  }

  // ---------------------------------------------------------------------------------
  // Spotify Logic - UPDATED with runtime config and safety checks
  // ---------------------------------------------------------------------------------

  private fun initialize(call: MethodCall, result: Result) {
    clientId = call.argument<String>("clientId")
    redirectUri = call.argument<String>("redirectUri")
    clientSecret = call.argument<String>("clientSecret")
    scope = call.argument<String>("scope")

    if (clientId != null && redirectUri != null && clientSecret != null && scope != null) {
      Log.d(TAG, "SpotikitPlugin initialized successfully.")
      result.success(true)
    } else {
      result.error("INITIALIZATION_FAILED", "Missing one or more configuration values.", null)
    }
  }

  private fun connectToSpotify(result: Result) {
    val currentClientId = clientId
    val currentRedirectUri = redirectUri
    if (currentClientId == null || currentRedirectUri == null) {
      result.error("NOT_INITIALIZED", "The plugin must be initialized before calling connectToSpotify.", null)
      return
    }

    if (spotifyAppRemote?.isConnected == true) {
      result.success("Already connected")
      return
    }

    val connectionParams = ConnectionParams.Builder(currentClientId)
      .setRedirectUri(currentRedirectUri)
      .showAuthView(true)
      .build()

    val connectionListener = object : Connector.ConnectionListener {
      override fun onConnected(appRemote: SpotifyAppRemote) {
        spotifyAppRemote = appRemote
        Log.d(TAG, "Spotify App Remote connected.")
        result.success("Connected")
      }
      override fun onFailure(throwable: Throwable) {
        Log.e(TAG, "Spotify connection failed: ${throwable.message}", throwable)
        result.error("CONNECTION_ERROR", "Could not connect to Spotify.", throwable.message)
      }
    }
    SpotifyAppRemote.connect(context, connectionParams, connectionListener)
  }

  private fun authenticateSpotify(result: Result) {
    val currentClientId = clientId
    val currentRedirectUri = redirectUri
    val currentScope = scope
    if (currentClientId == null || currentRedirectUri == null || currentScope == null) {
      result.error("NOT_INITIALIZED", "The plugin must be initialized before calling authenticateSpotify.", null)
      return
    }

    val currentActivity = activity
    if (currentActivity == null) {
      result.error("NO_ACTIVITY", "Cannot authenticate without a foreground activity.", null)
      return
    }

    val request = AuthorizationRequest.Builder(currentClientId, AuthorizationResponse.Type.CODE, currentRedirectUri)
      .setScopes(currentScope.split(" ").toTypedArray())
      .build()
    AuthorizationClient.openLoginActivity(currentActivity, AUTH_REQUEST_CODE, request)
    result.success("Authentication flow started")
  }

  // ========== Token Handling ==========

  private fun exchangeCodeForTokens(code: String) {
    val currentRedirectUri = redirectUri
    if (currentRedirectUri == null) {
      Log.e(TAG, "Cannot exchange code for tokens: plugin not initialized (missing redirect URI).")
      return
    }

    coroutineScope.launch {
      try {
        val responseBody = makeTokenRequest(
          FormBody.Builder()
            .add("grant_type", "authorization_code")
            .add("code", code)
            .add("redirect_uri", currentRedirectUri)
            .build()
        )

        if (responseBody != null) {
          processTokenResponse(responseBody)
          Log.d(TAG, "Successfully exchanged code for tokens.")
          withContext(Dispatchers.Main) {
            channel.invokeMethod("spotifyAuthSuccess", mapOf("accessToken" to accessToken))
          }
        } else {
          throw Exception("Token exchange response was null or unsuccessful")
        }
      } catch (e: Exception) {
        Log.e(TAG, "Error exchanging code for tokens", e)
        withContext(Dispatchers.Main) {
          channel.invokeMethod("spotifyAuthFailed", mapOf("error" to "token_exchange_failed", "message" to e.message))
        }
      }
    }
  }

  private fun makeTokenRequest(formBody: FormBody): String? {
    val currentClientId = clientId
    val currentClientSecret = clientSecret
    if (currentClientId == null || currentClientSecret == null) {
      Log.e(TAG, "Cannot make token request: plugin not initialized (missing client ID or secret).")
      return null // This will cause the calling function to throw an exception
    }

    val credentials = "$currentClientId:$currentClientSecret"
    val encodedCredentials = Base64.encodeToString(credentials.toByteArray(), Base64.NO_WRAP)

    val request = Request.Builder()
      .url("https://accounts.spotify.com/api/token")
      .addHeader("Authorization", "Basic $encodedCredentials")
      .post(formBody)
      .build()

    httpClient.newCall(request).execute().use { response ->
      if (!response.isSuccessful) {
        Log.e(TAG, "Token request failed with code ${response.code}: ${response.body?.string()}")
        return null
      }
      return response.body?.string()
    }
  }

  // ---------------------------------------------------------------------------------
  // No changes needed for the rest of the methods
  // ... (Your other methods like getAccessToken, logout, play, pause, etc. are correct)
  // ---------------------------------------------------------------------------------
  private fun getAccessToken(result: Result) {
    if (accessToken != null && System.currentTimeMillis() < tokenExpiresAt) {
      result.success(accessToken)
    } else if (refreshToken != null) {
      Log.d(TAG, "Access token expired. Refreshing...")
      refreshToken(result)
    } else {
      result.error("NO_TOKEN", "No valid token available. Please authenticate.", null)
    }
  }

  private fun logout(result: Result) {
    disconnect(object : Result {
      override fun success(res: Any?) {
        accessToken = null
        refreshToken = null
        tokenExpiresAt = 0
        sharedPreferences.edit().clear().apply()
        Log.d(TAG, "User logged out and all data cleared.")
        result.success("Logged out successfully")
      }
      override fun error(code: String, msg: String?, details: Any?) { result.error(code, msg, details) }
      override fun notImplemented() { result.notImplemented() }
    })
  }

  private fun play(spotifyUri: String, result: Result) {
    performActionIfConnected(result) { remote ->
      remote.playerApi.play(spotifyUri)
        .setResultCallback { result.success("Playback started for $spotifyUri") }
        .setErrorCallback { result.error("PLAY_ERROR", it.message, null) }
    }
  }

  private fun pause(result: Result) {
    performActionIfConnected(result) { remote ->
      remote.playerApi.pause()
        .setResultCallback { result.success("Playback paused") }
        .setErrorCallback { result.error("PAUSE_ERROR", it.message, null) }
    }
  }

  private fun resume(result: Result) {
    performActionIfConnected(result) { remote ->
      remote.playerApi.resume()
        .setResultCallback { result.success("Playback resumed") }
        .setErrorCallback { result.error("RESUME_ERROR", it.message, null) }
    }
  }

  private fun skipTrack(result: Result) {
    performActionIfConnected(result) { remote ->
      remote.playerApi.skipNext()
        .setResultCallback { result.success("Skipped to next track") }
        .setErrorCallback { result.error("SKIP_ERROR", it.message, null) }
    }
  }

  private fun previousTrack(result: Result) {
    performActionIfConnected(result) { remote ->
      remote.playerApi.skipPrevious()
        .setResultCallback { result.success("Skipped to previous track") }
        .setErrorCallback { result.error("PREVIOUS_ERROR", it.message, null) }
    }
  }

  private fun getTrackInfo(result: Result) {
    performActionIfConnected(result) { remote ->
      remote.playerApi.playerState.setResultCallback { playerState ->
        val track = playerState.track
        if (track != null) {
          result.success(mapOf(
            "artist" to track.artist.name,
            "name" to track.name,
            "uri" to track.uri,
            "isPaused" to playerState.isPaused
          ))
        } else {
          result.error("NO_TRACK", "No track is currently playing.", null)
        }
      }.setErrorCallback { result.error("STATE_ERROR", it.message, null) }
    }
  }

  private fun disconnect(result: Result) {
    spotifyAppRemote?.let {
      if (it.isConnected) {
        SpotifyAppRemote.disconnect(it)
        spotifyAppRemote = null
        Log.d(TAG, "Spotify App Remote disconnected.")
        result.success("Disconnected")
      } else {
        result.success("Already disconnected")
      }
    } ?: result.success("Not connected, no action taken")
  }

  private fun refreshToken(result: Result) {
    val currentRefreshToken = refreshToken
    if (currentRefreshToken == null) {
      result.error("NO_REFRESH_TOKEN", "No refresh token available.", null)
      return
    }

    coroutineScope.launch {
      try {
        val responseBody = makeTokenRequest(
          FormBody.Builder()
            .add("grant_type", "refresh_token")
            .add("refresh_token", currentRefreshToken)
            .build()
        )

        if (responseBody != null) {
          processTokenResponse(responseBody)
          Log.d(TAG, "Successfully refreshed tokens.")
          withContext(Dispatchers.Main) {
            result.success(accessToken)
          }
        } else {
          throw Exception("Token refresh response was null or unsuccessful")
        }
      } catch (e: Exception) {
        Log.e(TAG, "Error refreshing token", e)
        withContext(Dispatchers.Main) {
          result.error("REFRESH_ERROR", "Failed to refresh token", e.message)
        }
      }
    }
  }

  private fun processTokenResponse(responseBody: String) {
    val jsonObject = JSONObject(responseBody)
    accessToken = jsonObject.getString("access_token")
    refreshToken = jsonObject.optString("refresh_token", refreshToken)
    val expiresIn = jsonObject.getInt("expires_in")
    tokenExpiresAt = System.currentTimeMillis() + (expiresIn * 1000L)
    saveTokensToPrefs()
  }

  private fun saveTokensToPrefs() {
    with(sharedPreferences.edit()) {
      putString(KEY_ACCESS_TOKEN, accessToken)
      putString(KEY_REFRESH_TOKEN, refreshToken)
      putLong(KEY_TOKEN_EXPIRES_AT, tokenExpiresAt)
      apply()
    }
    Log.d(TAG, "Tokens saved to SharedPreferences.")
  }

  private fun loadTokensFromPrefs() {
    accessToken = sharedPreferences.getString(KEY_ACCESS_TOKEN, null)
    refreshToken = sharedPreferences.getString(KEY_REFRESH_TOKEN, null)
    tokenExpiresAt = sharedPreferences.getLong(KEY_TOKEN_EXPIRES_AT, 0)
    if (accessToken != null) {
      Log.d(TAG, "Tokens loaded from SharedPreferences.")
    }
  }

  private fun performActionIfConnected(result: Result, action: (SpotifyAppRemote) -> Unit) {
    val remote = spotifyAppRemote
    if (remote?.isConnected == true) {
      action(remote)
    } else {
      result.error("NOT_CONNECTED", "Spotify App Remote is not connected.", null)
    }
  }
}