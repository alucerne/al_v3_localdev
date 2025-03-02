BEGIN;
create extension "basejump-supabase_test_helpers" version '0.0.6';

select no_plan();

--- we insert a user into auth.users and return the id into user_id to use

select tests.create_supabase_user('test1', 'test1@test.com');

select tests.create_supabase_user('test2');

select tests.authenticate_as('test1');

-- users cannot insert into notifications
select throws_ok(
    $$ insert into public.notifications(account_id, body) values (tests.get_supabase_uid('test1'), 'test'); $$,
    'permission denied for table notifications'
);

set local role service_role;

-- service role can insert into notifications
select lives_ok(
    $$ insert into public.notifications(account_id, body) values (tests.get_supabase_uid('test1'), 'test'); $$,
    'service role can insert into notifications'
);

select tests.authenticate_as('test1');

-- user can read their own notifications
select row_eq(
    $$ select account_id, body from public.notifications where account_id = tests.get_supabase_uid('test1'); $$,
    row (tests.get_supabase_uid('test1'), 'test'::varchar),
    'user can read their own notifications'
);

-- user can read their team notifications
select makerkit.set_identifier('primary_owner', 'test@audiencelab.io');
select makerkit.set_identifier('owner', 'owner@audiencelab.io');
select makerkit.set_identifier('member', 'member@audiencelab.io');
select makerkit.set_identifier('custom', 'custom@audiencelab.io');

set local role service_role;

-- service role can insert into notifications
select lives_ok(
    $$ insert into public.notifications(account_id, body) values (makerkit.get_account_id_by_slug('audiencelab'), 'test'); $$,
    'service role can insert into notifications'
);

select tests.authenticate_as('member');

select row_eq(
    $$ select account_id, body from public.notifications where account_id = makerkit.get_account_id_by_slug('audiencelab'); $$,
    row (makerkit.get_account_id_by_slug('audiencelab'), 'test'::varchar),
    'user can read their team notifications'
);

-- foreigners

select tests.authenticate_as('test2');

-- foreigner cannot read other user's notifications
select is_empty(
    $$ select account_id, body from public.notifications where account_id = tests.get_supabase_uid('test1'); $$,
    'foreigner cannot read other users notifications'
);

-- foreigner cannot read other teams notifications
select is_empty(
    $$ select account_id, body from public.notifications where account_id = makerkit.get_account_id_by_slug('audiencelab'); $$,
    'foreigner cannot read other teams notifications'
);

select * from finish();

rollback;