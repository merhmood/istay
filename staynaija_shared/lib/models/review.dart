class Review {
  final String id;
  final String bookingId;
  final String listingId;
  final String guestId;
  final int cleanliness;
  final int communication;
  final int accuracy;
  final int locationRating;
  final int value;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.bookingId,
    required this.listingId,
    required this.guestId,
    required this.cleanliness,
    required this.communication,
    required this.accuracy,
    required this.locationRating,
    required this.value,
    required this.comment,
    required this.createdAt,
  });

  double get average => (cleanliness + communication + accuracy + locationRating + value) / 5;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'],
        bookingId: json['booking_id'],
        listingId: json['listing_id'],
        guestId: json['guest_id'],
        cleanliness: json['cleanliness'],
        communication: json['communication'],
        accuracy: json['accuracy'],
        locationRating: json['location_rating'],
        value: json['value'],
        comment: json['comment'],
        createdAt: DateTime.parse(json['created_at']),
      );
}
