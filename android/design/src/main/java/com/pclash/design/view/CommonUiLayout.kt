package com.pclash.design.view

import android.content.Context
import android.util.AttributeSet
import android.widget.LinearLayout
import com.pclash.design.common.CommonUiBuilder
import com.pclash.design.common.CommonUiScreen

class CommonUiLayout @JvmOverloads constructor(
    context: Context,
    attributeSet: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attributeSet, defStyleAttr) {
    val screen: CommonUiScreen = CommonUiScreen(this)

    init {
        orientation = VERTICAL
    }

    fun build(builder: CommonUiBuilder.() -> Unit) {
        screen.clear()

        CommonUiBuilder(screen).apply(builder)
    }
}