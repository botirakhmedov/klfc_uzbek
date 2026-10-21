package uz.alifbo.keyboard

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * A keyboard cannot switch itself on, so the launcher screen is the two settings
 * shortcuts the user needs, each with a line saying what it opens, and a field to try
 * the result in.
 */
class SetupActivity : Activity() {

    private val unit by lazy { resources.displayMetrics.density }

    private fun dp(value: Int) = (value * unit).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(40), dp(24), dp(32))
        }

        column.addView(TextView(this).apply {
            text = getString(R.string.setup_title)
            textSize = 26f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        })

        column.addView(TextView(this).apply {
            text = getString(R.string.setup_body)
            textSize = 15f
            alpha = 0.75f
            setLineSpacing(dp(4).toFloat(), 1f)
        }, spaced(top = 12))

        column.addView(step(R.string.setup_step_one, R.string.setup_step_one_note) {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }, spaced(top = 32))

        column.addView(step(R.string.setup_step_two, R.string.setup_step_two_note) {
            (getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager)
                .showInputMethodPicker()
        }, spaced(top = 20))

        column.addView(TextView(this).apply {
            text = getString(R.string.setup_try)
            textSize = 15f
            alpha = 0.75f
        }, spaced(top = 36))

        column.addView(EditText(this).apply {
            hint = getString(R.string.setup_hint)
            textSize = 18f
            gravity = Gravity.START or Gravity.TOP
            minLines = 3
        }, spaced(top = 8))

        setContentView(ScrollView(this).apply { addView(column) })
    }

    /** A labelled button with the sentence that explains where it goes. */
    private fun step(label: Int, note: Int, onClick: () -> Unit) =
        LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(Button(this@SetupActivity).apply {
                text = getString(label)
                setOnClickListener { onClick() }
            }, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
            addView(TextView(this@SetupActivity).apply {
                text = getString(note)
                textSize = 13f
                alpha = 0.6f
            }, spaced(top = 6, horizontal = 4))
        }

    private fun spaced(top: Int = 0, horizontal: Int = 0) =
        LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT).apply {
            topMargin = dp(top)
            leftMargin = dp(horizontal)
            rightMargin = dp(horizontal)
        }
}
