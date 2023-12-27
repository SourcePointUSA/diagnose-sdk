package com.sourcepoint.diagnose

interface ConsentManager {

    fun isIabConsented(iabId: Int, consentString: String): Boolean
}
