# Troubleshooting PostgreSQL

The following are possible solutions to problems you might encounter with PostgreSQL and GDK.

## `gdk update` leaves `gitlab/db/structure.sql` with uncommitted changes

If you have uncommitted changes in `gitlab/db/structure.sql` after a `gdk update` (see
[GitLab#300251](https://gitlab.com/gitlab-org/gitlab/-/issues/300251)), you can either:

- Add [GDK hook](../configuration.md#hooks) to your `gdk.yml` with the following (do this if you are
  unfamiliar with `db/structure.sql`):

  ```yaml
  gdk:
    update_hooks:
      after:
        - cd gitlab && git checkout db/structure.sql
  ```

- Refer to the developer documentation for
  [schema changes](https://docs.gitlab.com/ee/development/migration_style_guide.html#schema-changes).

## Unable to build and install `pg` gem on GDK install

After installing PostgreSQL with brew, you have to set the proper path to PostgreSQL.
You may run into the following errors on running `gdk install`

```plaintext
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.

    current directory: /Users/gdk/.rvm/gems/ruby-2.3.3/gems/pg-0.18.4/ext
/Users/gdk/.rvm/rubies/ruby-2.3.3/bin/ruby -r ./siteconf20180330-95521-1k5x76v.rb extconf.rb
checking for pg_config... no
No pg_config... trying anyway. If building fails, please try again with
 --with-pg-config=/path/to/pg_config

 ...

An error occurred while installing pg (0.18.4), and Bundler cannot continue.
Make sure that `gem install pg -v '0.18.4'` succeeds before bundling.
```

This is because the script fails to find the PostgreSQL instance in the path.
The instructions for this may show up after installing PostgreSQL.
The example below is from running `brew install postgresql@11` on a macOS installation.
For other versions, other platform install and other shell terminal please adjust the path accordingly.

```plaintext
If you need to have this software first in your PATH run:
  echo 'export PATH="/usr/local/opt/postgresql@11/bin:$PATH"' >> ~/.bash_profile
```

Once this is set, run the `gdk install` command again.

## Error in database migrations when pg_trgm extension is missing

Since GitLab 8.6+ the PostgreSQL extension `pg_trgm` must be installed. If you
are installing GDK for the first time this is handled automatically from the
database schema. In case you are updating your GDK and you experience this
error, make sure you pull the latest changes from the GDK repository and run:

```shell
./support/enable-postgres-extensions
```

## PostgreSQL is looking for wrong version of icu4c

If the Rails server cannot connect to PostgreSQL and you see the following when running `gdk tail postgresql`:

```plaintext
2020-07-06_00:26:20.51557 postgresql            : support/postgresql-signal-wrapper:16:in `<main>': undefined method `exitstatus' for nil:NilClass (NoMethodError)
2020-07-06_00:26:21.62892 postgresql            : dyld: Library not loaded: /usr/local/opt/icu4c/lib/libicui18n.66.dylib
2020-07-06_00:26:21.62896 postgresql            :   Referenced from: /usr/local/opt/postgresql@11/bin/postgres
2020-07-06_00:26:21.62897 postgresql            :   Reason: image not found
```

This means the PostgreSQL is trying to load an older version of `icu4c` (`66` in the example), and failing.
This can happen when `icu4c` is not pinned and is upgraded beyond the version supported
by PostgreSQL.

To resolve this, reinstall PostgreSQL with:

```shell
brew reinstall postgresql@11
```

## ActiveRecord::PendingMigrationError at /

After running the GitLab Development Kit using `gdk start` and browsing to `http://localhost:3000/`, you may see an error page that says `ActiveRecord::PendingMigrationError at /. Migrations are pending`.

To fix this error, the pending migration must be resolved. Perform the following steps in your terminal:

1. Change to the `gitlab` directory using `cd gitlab`
1. Run the following command to perform the migration: `rails db:migrate RAILS_ENV=development`

Once the operation is complete, refresh the page.

## Database files incompatible with server

If you see `FATAL: database files are incompatible with server` errors, it means
the PostgreSQL data directory was initialized by an old PostgreSQL version, which
is not compatible with your current PostgreSQL version.

You can solve it in one of two ways, depending if you would like to retain your data or not:

## If you do not need to retain your data

Note that this wipes out the existing contents of your database.

```shell
# cd into your GDK folder
cd gitlab-development-kit

# Remove your existing data
mv postgresql/data postgresql/data.bkp

# Initialize a new data folder
make postgresql/data

# Initialize the gitlabhq_development database
gdk reconfigure

# Start your database.
gdk start db
```

You may remove the `data.bkp` folder if your database is working well.

## If you would like to retain your data

Check the version of PostgreSQL that your data is compatible with:

```shell
# cd into your GDK folder
cd gitlab-development-kit

cat postgresql/data/PG_VERSION
```

If the content of the `PG_VERSION` file is `10`, your data folder is compatible
with PostgreSQL 10.

Downgrade your PostgreSQL to the compatible version. For example, to downgrade to
PostgreSQL 10 on macOS using Homebrew:

```shell
brew install postgresql@10
brew link --force postgresql@10
```

You also need to update your `Procfile` to use the downgraded PostgreSQL binaries:

```shell
# Change Procfile to use downgraded PostgreSQL binaries
gdk reconfigure
```

You can now follow the steps described in [Upgrade PostgreSQL](../howto/postgresql.md#upgrade-postgresql)
to upgrade your PostgreSQL version while retaining your current data.

## Rails cannot connect to PostgreSQL

- Use `gdk status` to see if `postgresql` is running.
- Check for custom PostgreSQL connection settings defined via the environment; we
  assume none such variables are set. Look for them with `set | grep '^PG'`.

## Fix conflicts in database migrations if you use the same db for CE and EE

NOTE:
The recommended way to fix the problem is to rebuild your database and move
your EE development into a new directory.

In case you use the same database for both CE and EE development, sometimes you
can get stuck in a situation when the migration is up in `rake db:migrate:status`,
but in reality the database doesn't have it.

For example, <https://gitlab.com/gitlab-org/gitlab-foss/merge_requests/3186>
introduced some changes when a few EE migrations were added to CE. If you were
using the same db for CE and EE you would get hit by the following error:

```shell
undefined method `share_with_group_lock' for #<Group
```

This exception happened because the system thinks that such migration was
already run, and thus Rails skipped adding the `share_with_group_lock` field to
the `namespaces` table.

The problem is that you can not run `rake db:migrate:up VERSION=xxx` since the
system thinks the migration is already run. Also, you can not run
`rake db:migrate:redo VERSION=xxx` since it tries to do `down` before `up`,
which fails if column does not exist or can cause data loss if column exists.

A quick solution is to remove the database data and then recreate it:

```shell
bundle exec rake setup
```

---

If you don't want to nuke the database, you can perform the migrations manually.
Open a terminal and start the rails console:

```shell
rails console
```

And run manually the migrations:

```plaintext
require Rails.root.join("db/migrate/20130711063759_create_project_group_links.rb")
CreateProjectGroupLinks.new.change
require Rails.root.join("db/migrate/20130820102832_add_access_to_project_group_link.rb")
AddAccessToProjectGroupLink.new.change
require Rails.root.join("db/migrate/20150930110012_add_group_share_lock.rb")
AddGroupShareLock.new.change
```

You should now be able to continue your development. You might want to note
that in this case we had 3 migrations happening:

```plaintext
db/migrate/20130711063759_create_project_group_links.rb
db/migrate/20130820102832_add_access_to_project_group_link.rb
db/migrate/20150930110012_add_group_share_lock.rb
```

In general it doesn't matter in which order you run them, but in this case
the last two migrations create columns in a table which is created by the first
migration. So, in this example the order is important. Otherwise you would try
to create a column in a non-existent table which would of course fail.

## Delete non-existent migrations from the database

If for some reason you end up having database migrations that no longer exist
but are present in your database, you might want to remove them.

1. Find the non-existent migrations with `rake db:migrate:status`. You should
   see some entries like:

   ```plaintext
   up     20160727191041  ********** NO FILE **********
   up     20160727193336  ********** NO FILE **********
   ```

1. Open a rails database console with `rails dbconsole`.
1. Delete the migrations you want with:

   ```sql
   DELETE FROM schema_migrations WHERE version='20160727191041';
   ```

You can now run `rake db:migrate:status` again to verify that the entries are
deleted from the database.
