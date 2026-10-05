-- HuntNexus Brain — RubinOT collection access metadata.
alter table sources add column if not exists collection_method text;
alter table sources add column if not exists last_access_status text;
alter table sources add column if not exists last_checked_at timestamptz;
