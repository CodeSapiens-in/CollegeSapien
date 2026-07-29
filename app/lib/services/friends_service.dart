import '../models/friend_models.dart';
import 'api_service.dart';

class FriendsService {
  Future<FriendsOverview> getOverview() async {
    final json = await ApiService.instance.get('/friends/overview') as Map<String, dynamic>;
    return FriendsOverview.fromJson(json);
  }

  Future<void> sendRequest(String email) =>
      ApiService.instance.post('/friends/requests', {'email': email});

  Future<void> acceptRequest(String requestId) =>
      ApiService.instance.post('/friends/requests/$requestId/accept');

  Future<void> rejectRequest(String requestId) =>
      ApiService.instance.post('/friends/requests/$requestId/reject');

  Future<void> removeFriend(String uid) => ApiService.instance.delete('/friends/$uid');
}
