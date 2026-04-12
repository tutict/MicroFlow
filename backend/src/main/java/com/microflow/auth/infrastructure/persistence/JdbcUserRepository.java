package com.microflow.auth.infrastructure.persistence;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcUserRepository {

    private static final RowMapper<UserAccountRow> USER_MAPPER = JdbcUserRepository::mapUser;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    public JdbcUserRepository(JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    public Optional<UserAccountRow> findByEmail(String email) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject("""
                    SELECT id, email, password_hash, display_name
                    FROM users
                    WHERE email = ?
                    """, USER_MAPPER, email));
        } catch (EmptyResultDataAccessException ex) {
            return Optional.empty();
        }
    }

    public Optional<UserAccountRow> findById(String userId) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject("""
                    SELECT id, email, password_hash, display_name
                    FROM users
                    WHERE id = ?
                    """, USER_MAPPER, userId));
        } catch (EmptyResultDataAccessException ex) {
            return Optional.empty();
        }
    }

    public UserAccountRow create(String email, String passwordHash, String displayName) {
        var userId = "usr_" + UUID.randomUUID();
        var now = Instant.now(clock).toString();
        jdbcTemplate.update("""
                INSERT INTO users(id, email, password_hash, display_name, status, created_at, updated_at)
                VALUES (?, ?, ?, ?, 'ACTIVE', ?, ?)
                """, userId, email, passwordHash, displayName, now, now);
        return new UserAccountRow(userId, email, passwordHash, displayName);
    }

    private static UserAccountRow mapUser(ResultSet rs, int rowNum) throws SQLException {
        return new UserAccountRow(
                rs.getString("id"),
                rs.getString("email"),
                rs.getString("password_hash"),
                rs.getString("display_name")
        );
    }
}

