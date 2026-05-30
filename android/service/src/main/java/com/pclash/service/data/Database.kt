package com.pclash.service.data

import android.content.Context
import androidx.room.Room
import androidx.room.RoomDatabase
import com.pclash.common.Global
import com.pclash.service.data.migrations.MIGRATIONS
import androidx.room.Database as DatabaseMetadata

@DatabaseMetadata(
    version = 4,
    exportSchema = false,
    entities = [ProfileEntity::class, SelectedProxyEntity::class]
)
abstract class Database : RoomDatabase() {
    abstract fun openProfileDao(): ProfileDao
    abstract fun openSelectedProxyDao(): SelectedProxyDao

    companion object {
        val database = open(Global.application)

        private fun open(context: Context): Database {
            return Room.databaseBuilder(
                context.applicationContext,
                Database::class.java,
                "clash-config"
            ).addMigrations(*MIGRATIONS).build()
        }
    }
}