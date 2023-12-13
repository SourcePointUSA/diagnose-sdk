import com.sourcepoint.diagnose.VendorDatabaseImpl
import kotlin.io.println

fun main() {
    // Read the input value.
    println("Hello, enter your name:")
    val vendorDb = VendorDatabaseImpl("version", HashMap())
    println("${vendorDb.getVendorId("test")}")
    val name = readln()
    // Count the letters in the name.
    name.replace(" ", "").let { println("Your name contains ${it.length} letters") }
}
