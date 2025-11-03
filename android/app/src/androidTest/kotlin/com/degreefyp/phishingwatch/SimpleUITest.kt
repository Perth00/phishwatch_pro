package com.degreefyp.phishingwatch

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.ext.junit.rules.ActivityScenarioRule
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import androidx.test.espresso.Espresso.onView
import androidx.test.espresso.assertion.ViewAssertions.matches
import androidx.test.espresso.matcher.ViewMatchers.isDisplayed
import androidx.test.espresso.matcher.ViewMatchers.isRoot

@RunWith(AndroidJUnit4::class)
class SimpleUITest {

	@get:Rule
	val activityRule = ActivityScenarioRule(MainActivity::class.java)

	@Test
	fun appLaunches_rootIsDisplayed() {
		onView(isRoot()).check(matches(isDisplayed()))
	}
}


