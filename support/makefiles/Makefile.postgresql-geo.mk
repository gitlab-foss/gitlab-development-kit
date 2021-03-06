postgresql/geo: postgresql-geo/data postgresql/geo/port postgresql/geo/seed-data

postgresql-geo/data:
ifeq ($(geo_enabled),true)
	$(Q)${postgresql_bin_dir}/initdb --locale=C -E utf-8 postgresql-geo/data
else
	@true
endif

postgresql/geo/port: postgresql-geo/data
ifeq ($(geo_enabled),true)
	$(Q)support/postgres-port ${postgresql_geo_dir} ${postgresql_geo_port}
else
	@true
endif

postgresql/geo/Procfile:
	$(Q)grep '^postgresql-geo:' Procfile || (printf ',s/^#postgresql-geo/postgresql-geo/\nwq\n' | ed -s Procfile)

postgresql/geo/seed-data:
	$(Q)support/bootstrap-geo

postgresql-geo-replication-primary: postgresql-geo-replication/access postgresql-replication/role postgresql-replication/config

postgresql-geo-secondary-replication/access:
	$(Q)cat support/pg_hba.conf.add >> ${postgresql_data_dir}/pg_hba.conf

postgresql-geo-replication/access:
	$(Q)cat support/pg_hba.conf.add >> ${postgresql_data_dir}/pg_hba.conf

postgresql-geo-secondary-replication/data:
	${postgresql_bin_dir}/initdb --locale=C -E utf-8 ${postgresql_data_dir}
