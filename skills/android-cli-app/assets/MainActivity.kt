package APP_PACKAGE

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize()) { Hello() }
            }
        }
    }
}

@Composable
fun Hello() {
    // 폴더블: 접고 펴면 Configuration 이 바뀌어 dp 가 바로 다시 그려진다
    val c = LocalConfiguration.current
    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Hello, Fold", style = MaterialTheme.typography.headlineMedium)
        Text("화면 ${c.screenWidthDp} x ${c.screenHeightDp} dp")
        Text("빌드 ${BuildConfig.BUILD_TIME}")
    }
}
