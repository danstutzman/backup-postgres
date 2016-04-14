create table test_rows (
  id serial,
  inserted_at timestamptz,
  primary key (id)
);

insert into test_rows (inserted_at) values ('now');
