import 'hasura_manager.dart';

class AddressService {
  final _hasura = HasuraManager.instance;

  Future<List<Map<String, dynamic>>> getAddresses(String userId) async {
    const query = r'''
      query GetAddresses($user_id: bigint!) {
        user_addresses(where: {user_id: {_eq: $user_id}}, order_by: {created_at: desc}) {
          id
          user_id
          address_name
          address_type
          country
          city
          district
          full_address
          postal_code
          tax_or_tc_no
          tax_address
          company_name
          created_at
        }
      }
    ''';

    final data = await _hasura.graphQLRequest(query: query, variables: {
      "user_id": userId,
    });

    return List<Map<String, dynamic>>.from(data["user_addresses"] ?? []);
  }

  Future<bool> addAddress({
    required String userId,
    required String addressType,
    required String addressName,
    required String country,
    required String city,
    required String district,
    required String fullAddress,
    String? postalCode,
    String? taxOrTcNo,
    String? taxAddress,
    String? companyName,
  }) async {
    const mutation = r'''
      mutation InsertUserAddress(
        $user_id: bigint!,
        $address_type: String!,
        $address_name: String!,
        $country: String!,
        $city: String!,
        $district: String!,
        $full_address: String!,
        $postal_code: String,
        $tax_or_tc_no: String,
        $tax_address: String,
        $company_name: String
      ) {
        insert_user_addresses_one(object: {
          user_id: $user_id,
          address_type: $address_type,
          address_name: $address_name,
          country: $country,
          city: $city,
          district: $district,
          full_address: $full_address,
          postal_code: $postal_code,
          tax_or_tc_no: $tax_or_tc_no,
          tax_address: $tax_address,
          company_name: $company_name
        }) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "user_id": userId,
      "address_type": addressType,
      "address_name": addressName,
      "country": country,
      "city": city,
      "district": district,
      "full_address": fullAddress,
      "postal_code": postalCode,
      "tax_or_tc_no": taxOrTcNo,
      "tax_address": taxAddress,
      "company_name": companyName,
    });

    return true;
  }

  Future<bool> updateAddress({
    required int id,
    required String addressType,
    required String addressName,
    required String country,
    required String city,
    required String district,
    required String fullAddress,
    String? postalCode,
    String? taxOrTcNo,
    String? taxAddress,
    String? companyName,
  }) async {
    const mutation = r'''
      mutation UpdateUserAddress(
        $id: Int!,
        $address_type: String!,
        $address_name: String!,
        $country: String!,
        $city: String!,
        $district: String!,
        $full_address: String!,
        $postal_code: String,
        $tax_or_tc_no: String,
        $tax_address: String,
        $company_name: String
      ) {
        update_user_addresses_by_pk(
          pk_columns: {id: $id},
          _set: {
            address_type: $address_type,
            address_name: $address_name,
            country: $country,
            city: $city,
            district: $district,
            full_address: $full_address,
            postal_code: $postal_code,
            tax_or_tc_no: $tax_or_tc_no,
            tax_address: $tax_address,
            company_name: $company_name
          }
        ) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {
      "id": id,
      "address_type": addressType,
      "address_name": addressName,
      "country": country,
      "city": city,
      "district": district,
      "full_address": fullAddress,
      "postal_code": postalCode,
      "tax_or_tc_no": taxOrTcNo,
      "tax_address": taxAddress,
      "company_name": companyName,
    });

    return true;
  }

  Future<bool> deleteAddress(int id) async {
    const mutation = r'''
      mutation DeleteAddress($id: Int!) {
        delete_user_addresses_by_pk(id: $id) { id }
      }
    ''';

    await _hasura.graphQLRequest(query: mutation, variables: {"id": id});
    return true;
  }
}
