package com.wayaspot.forexbot.service;

import com.wayaspot.forexbot.config.AppProps;
import com.wayaspot.forexbot.entity.AdminUser;
import com.wayaspot.forexbot.repo.AdminUserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/** Creates the super admin on first start (no public registration exists). */
@Component
public class DataSeeder implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);
    private final AdminUserRepository users;
    private final PasswordEncoder encoder;
    private final AppProps props;

    public DataSeeder(AdminUserRepository users, PasswordEncoder encoder, AppProps props) {
        this.users = users;
        this.encoder = encoder;
        this.props = props;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (users.existsByRole("SUPER_ADMIN")) return;
        AdminUser u = new AdminUser();
        u.setUsername(props.getAdminUsername());
        u.setPasswordHash(encoder.encode(props.getAdminPassword()));
        u.setRole("SUPER_ADMIN");
        users.save(u);
        log.info("Super admin '{}' created", props.getAdminUsername());
    }
}
