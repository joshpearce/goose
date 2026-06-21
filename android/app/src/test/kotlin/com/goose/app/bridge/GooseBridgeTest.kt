package com.goose.app.bridge

import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * JVM unit tests for GooseBridge.
 *
 * System.loadLibrary("goose_core") cannot run in a JVM unit test — there is
 * no .so on the JVM library path. These tests cover the Kotlin wrapper logic
 * only, specifically that error paths produce valid JSON with "ok":false.
 *
 * Full native integration (handle("{}") returns JSON) is verified by
 * ./gradlew assembleDebug and on-device instrumented tests in Phase 107.
 */
class GooseBridgeTest {

    @Test
    fun buildErrorJsonContainsOkFalse() {
        val method = GooseBridge::class.java.getDeclaredMethod(
            "buildErrorJson",
            String::class.java
        )
        method.isAccessible = true
        val result = method.invoke(GooseBridge, "test error") as String
        assertTrue("Error JSON must contain \"ok\":false", result.contains("\"ok\":false"))
        assertTrue("Error JSON must contain error message", result.contains("test error"))
        assertTrue("Error JSON must contain \"result\":null", result.contains("\"result\":null"))
    }

    @Test
    fun buildErrorJsonEscapesBackslashesAndQuotes() {
        val method = GooseBridge::class.java.getDeclaredMethod(
            "buildErrorJson",
            String::class.java
        )
        method.isAccessible = true
        val result = method.invoke(GooseBridge, "error with \"quotes\" and \\backslash") as String
        assertTrue("Quotes must be escaped in JSON", result.contains("\\\"quotes\\\""))
        assertTrue("Backslashes must be escaped in JSON", result.contains("\\\\backslash"))
    }

    @Test
    fun buildErrorJsonStructureIsValid() {
        val method = GooseBridge::class.java.getDeclaredMethod(
            "buildErrorJson",
            String::class.java
        )
        method.isAccessible = true
        val result = method.invoke(GooseBridge, "some error") as String
        assertTrue("Must contain ok field", result.contains("\"ok\""))
        assertTrue("Must contain result field", result.contains("\"result\""))
        assertTrue("Must contain error field", result.contains("\"error\""))
        assertTrue("Must contain timing field", result.contains("\"timing\""))
    }
}
