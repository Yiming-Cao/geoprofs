// test/mocks/mock_supabase.dart
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockPostgrestClient extends Mock implements PostgrestClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockFunctionsClient extends Mock implements FunctionsClient {}
