import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.inMemoryDriver
import com.sourcepoint.diagnose.DiagnoseDatabase
import com.sourcepoint.diagnose.DiagnoseDatabaseImpl
import com.sourcepoint.diagnose.MonotonicClockImpl
import com.sourcepoint.diagnose.storage.DiagnoseConfig
import com.sourcepoint.diagnose.storage.DiagnoseStorage
import io.github.oshai.kotlinlogging.KotlinLogging
import kotlinx.collections.immutable.persistentListOf
import kotlinx.collections.immutable.persistentSetOf
import kotlinx.coroutines.runBlocking

private val logger = KotlinLogging.logger {}

fun main() {
    logger.error { "logging test" }
    runBlocking {
        val driver: SqlDriver = inMemoryDriver(DiagnoseStorage.Schema)
        val clock = MonotonicClockImpl()
        val db: DiagnoseDatabase = DiagnoseDatabaseImpl(driver, clock)
        val config = DiagnoseConfig(0.5, persistentSetOf("test.com"), null, null, persistentListOf())
        db.addConfig(config)
        val latestConfig = db.getLatestConfig()
        println(latestConfig)
    }
}
