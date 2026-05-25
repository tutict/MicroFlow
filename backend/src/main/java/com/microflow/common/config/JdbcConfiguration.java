package com.microflow.common.config;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Singleton;
import javax.sql.DataSource;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.sqlite.SQLiteDataSource;
import org.springframework.jdbc.core.JdbcTemplate;

@ApplicationScoped
public class JdbcConfiguration {

    @ConfigProperty(name = "microflow.database.path", defaultValue = "./microflow.db")
    String databasePath;

    @Produces
    @Singleton
    DataSource dataSource() {
        var dataSource = new SQLiteDataSource();
        dataSource.setUrl("jdbc:sqlite:" + databasePath);
        dataSource.setBusyTimeout(5_000);
        return dataSource;
    }

    @Produces
    @Singleton
    JdbcTemplate jdbcTemplate(DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}
