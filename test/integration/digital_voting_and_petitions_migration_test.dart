import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task 1: Kiem tra Migration SQL Bieu Quyet Dien Tu & Kien Nghi Cong Dong D7', () {
    const migrationPath = 'supabase/migrations/20261103_02_digital_voting_and_petitions.sql';

    test('1. Tap tin migration 20261103_02 phai ton tai', () {
      final file = File(migrationPath);
      expect(file.existsSync(), isTrue, reason: 'Tập tin migration D7 phải tồn tại');
    });

    test('2. Migration phai dinh nghia bang polls, poll_options, poll_votes va RLS', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final sql = file.readAsStringSync();
      expect(sql.contains('CREATE TABLE IF NOT EXISTS polls'), isTrue);
      expect(sql.contains('CREATE TABLE IF NOT EXISTS poll_options'), isTrue);
      expect(sql.contains('CREATE TABLE IF NOT EXISTS poll_votes'), isTrue);
      expect(sql.contains('vote_weight_type'), isTrue);
      expect(sql.contains('choice_type'), isTrue);
      expect(sql.contains('ALTER TABLE polls ENABLE ROW LEVEL SECURITY;'), isTrue);
      expect(sql.contains('ALTER TABLE poll_votes ENABLE ROW LEVEL SECURITY;'), isTrue);
      expect(sql.contains('UNIQUE(poll_id, apartment_id)'), isTrue);
    });

    test('3. Migration phai dinh nghia bang resident_petitions va petition_endorsements', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final sql = file.readAsStringSync();
      expect(sql.contains('CREATE TABLE IF NOT EXISTS resident_petitions'), isTrue);
      expect(sql.contains('CREATE TABLE IF NOT EXISTS petition_endorsements'), isTrue);
      expect(sql.contains('endorsement_count'), isTrue);
      expect(sql.contains('official_response'), isTrue);
      expect(sql.contains('ALTER TABLE resident_petitions ENABLE ROW LEVEL SECURITY;'), isTrue);
      expect(sql.contains('ALTER TABLE petition_endorsements ENABLE ROW LEVEL SECURITY;'), isTrue);
      expect(sql.contains('UNIQUE(petition_id, apartment_id)'), isTrue);
    });

    test('4. Migration phai dinh nghia cac triggers sinh ma tu dong POLL- va PET-', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final sql = file.readAsStringSync();
      expect(sql.contains('POLL-'), isTrue);
      expect(sql.contains('PET-'), isTrue);
      expect(sql.contains('trg_generate_poll_code'), isTrue);
      expect(sql.contains('trg_generate_petition_code'), isTrue);
    });

    test('5. Migration phai dinh nghia day du 4 RPCs ho tro nghiep vu bieu quyet va kien nghi', () {
      final file = File(migrationPath);
      if (!file.existsSync()) return;

      final sql = file.readAsStringSync();
      expect(sql.contains('CREATE OR REPLACE FUNCTION submit_poll_vote'), isTrue);
      expect(sql.contains('CREATE OR REPLACE FUNCTION get_poll_results'), isTrue);
      expect(sql.contains('CREATE OR REPLACE FUNCTION endorse_petition'), isTrue);
      expect(sql.contains('CREATE OR REPLACE FUNCTION update_petition_response'), isTrue);
    });
  });
}

