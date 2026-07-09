package com.microflow.auth.infrastructure.persistence;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcRefreshTokenRepository {

    private static final RowMapper<RefreshTokenRow> REFRESH_TOKEN_MAPPER = JdbcRefreshTokenRepository::mapRefreshToken;

    private final JdbcTemplate jdbcTemplate;

    public JdbcRefreshTokenRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void create(String id, String userId, String tokenHash, String expiresAt, String createdAt) {
        jdbcTemplate.update("""
                INSERT INTO refresh_tokens(id, user_id, token_hash, expires_at, revoked_at, created_at)
                VALUES (?, ?, ?, ?, NULL, ?)
                """, id, userId, tokenHash, expiresAt, createdAt);
    }

    public Optional<RefreshTokenRow> findActiveByHash(String tokenHash, Instant now) {
        return jdbcTemplate.query("""
                SELECT id, user_id, token_hash, expires_at, revoked_at, created_at
                FROM refresh_tokens
                WHERE token_hash = ? AND revoked_at IS NULL
                LIMIT 1
                """, REFRESH_TOKEN_MAPPER, tokenHash).stream()
                .filter(row -> Instant.parse(row.expiresAt()).isAfter(now))
                .findFirst();
    }

    public void revokeByHash(String tokenHash, String revokedAt) {
        jdbcTemplate.update("""
                UPDATE refresh_tokens
                SET revoked_at = ?
                WHERE token_hash = ? AND revoked_at IS NULL
                """, revokedAt, tokenHash);
    }

    private static RefreshTokenRow mapRefreshToken(ResultSet rs, int rowNum) throws SQLException {
        return new RefreshTokenRow(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("token_hash"),
                rs.getString("expires_at"),
                rs.getString("revoked_at"),
                rs.getString("created_at")
        );
    }
}
