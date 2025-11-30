import '../hasura_manager.dart';

class AdminBookService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAllBooks() async {
    const query = r'''
query GetAllBooks {
  books(order_by: {id: desc}) {
    id
    title
    isbn
    cover_url
    book_url
    price
    discount_price
    description
    min_description
    author_id
    category_id

    author_rel: authorByAuthorId {
      id
      name
    }

    category_rel: categoryByCategoryId {
      id
      name
    }
  }
}
  ''';

    final data = await _hasura.graphQLRequest(query: query);
    return List<Map<String, dynamic>>.from(data["books"]);
  }

  Future<bool> addBook({
    required String title,
    required String isbn,
    required double price,
    String? coverUrl,
    String? bookUrl,
    double? discountPrice,
    int? categoryId,
    int? authorId,
    String? description,
    String? minDescription,
  }) async {
    const mutation = r'''
    mutation AddBook(
      $title: String!,
      $isbn: String!,
      $cover_url: String,
      $book_url: String,
      $price: numeric!,
      $discount_price: numeric,
      $category_id: Int,
      $author_id: Int,
      $description: String,
      $min_description: String
    ) {
      insert_books_one(object: {
        title: $title,
        isbn: $isbn,
        cover_url: $cover_url,
        book_url: $book_url,
        price: $price,
        discount_price: $discount_price,
        category_id: $category_id,
        author_id: $author_id,
        description: $description,
        min_description: $min_description
      }) {
        id
      }
    }
  ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "title": title,
        "isbn": isbn,
        "cover_url": coverUrl,
        "book_url": bookUrl,
        "price": price,
        "discount_price": discountPrice,
        "category_id": categoryId,
        "author_id": authorId,
        "description": description,
        "min_description": minDescription,
      },
    );

    return true;
  }

  Future<bool> updateBook({
    required int id,
    required String title,
    required String isbn,
    required double price,
    String? coverUrl,
    String? bookUrl,
    double? discountPrice,
    int? categoryId,
    int? authorId,
    String? description,
    String? minDescription,
  }) async {
    const mutation = r'''
    mutation UpdateBook(
      $id: Int!,
      $title: String!,
      $isbn: String!,
      $cover_url: String,
      $book_url: String,
      $price: numeric!,
      $discount_price: numeric,
      $category_id: Int,
      $author_id: Int,
      $description: String,
      $min_description: String
    ) {
      update_books_by_pk(
        pk_columns: {id: $id},
        _set: {
          title: $title,
          isbn: $isbn,
          cover_url: $cover_url,
          book_url: $book_url,
          price: $price,
          discount_price: $discount_price,
          category_id: $category_id,
          author_id: $author_id,
          description: $description,
          min_description: $min_description
        }
      ) {
        id
      }
    }
  ''';

    await _hasura.graphQLRequest(
      query: mutation,
      variables: {
        "id": id,
        "title": title,
        "isbn": isbn,
        "cover_url": coverUrl,
        "book_url": bookUrl,
        "price": price,
        "discount_price": discountPrice,
        "category_id": categoryId,
        "author_id": authorId,
        "description": description,
        "min_description": minDescription,
      },
    );

    return true;
  }

  Future<bool> deleteBook(int id) async {
    const mutation = r'''
      mutation DeleteBook($id: Int!) {
        delete_books_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});

    return true;
  }

  Future<Map<String, dynamic>?> getBookById(int id) async {
    const query = r'''
      query GetBook($id: Int!) {
        books_by_pk(id: $id) {
          id
          title
          author_id
          cover_url
          book_url
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(
      query: query,
      variables: {"id": id},
    );

    return data["books_by_pk"] as Map<String, dynamic>?;
  }
}
