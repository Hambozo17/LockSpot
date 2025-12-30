class Location {
  final String name;
  final double distance;
  final double price;
  final String availability;
  final String imageUrl;
  final Map<String, dynamic> sizes;

  Location({
    required this.name,
    required this.distance,
    required this.price,
    required this.availability,
    required this.imageUrl,
    required this.sizes,
  });

  factory Location.fromMap(Map<String, dynamic> data) {
    return Location(
      name: data['name'] ?? 'Unnamed Location',
      distance: (data['distance'] ?? 0.0).toDouble(),
      price: (data['price'] ?? 0.0).toDouble(),
      availability: data['availability'] ?? 'Unknown',
      imageUrl: data['imageUrl'] ?? '',
      sizes: data['sizes'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'distance': distance,
      'price': price,
      'availability': availability,
      'imageUrl': imageUrl,
      'sizes': sizes,
    };
  }
}