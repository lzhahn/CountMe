import Foundation

extension String {
    func percentEncoded() -> String {
        var allowedCharacters = CharacterSet.alphanumerics
        allowedCharacters.insert(charactersIn: "-._~")
        return self.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? self
    }
}

func generateSignatureBaseString(
    httpMethod: String,
    url: String,
    parameters: [String: String]
) -> String {
    // 1. Percent encode keys and values
    let encodedParams = parameters.map { (key, value) in
        (key.percentEncoded(), value.percentEncoded())
    }
    
    // 2. Sort parameters alphabetically by encoded key
    let sortedParams = encodedParams.sorted { $0.0 < $1.0 }
    
    // 3. Create parameter string (encodedKey=encodedValue&...)
    let parameterString = sortedParams
        .map { "\($0.0)=\($0.1)" }
        .joined(separator: "&")
    
    // 4. Percent encode the HTTP method, URL, and parameter string
    let encodedMethod = httpMethod.uppercased().percentEncoded()
    let encodedURL = url.percentEncoded()
    let encodedParamString = parameterString.percentEncoded()
    
    // 5. Concatenate with & separator
    return "\(encodedMethod)&\(encodedURL)&\(encodedParamString)"
}

let httpMethod = "GET"
let url = "https://platform.fatsecret.com/rest/server.api"
let parameters = [
    "oauth_consumer_key": "test_key",
    "oauth_nonce": "test_nonce",
    "oauth_signature_method": "HMAC-SHA1",
    "oauth_timestamp": "1234567890",
    "oauth_version": "1.0",
    "method": "foods.search",
    "search_expression": "apple"
]

let baseString = generateSignatureBaseString(
    httpMethod: httpMethod,
    url: url,
    parameters: parameters
)

print("Base string:")
print(baseString)
print("\nChecking for specific patterns:")
print("Starts with GET%26: \(baseString.hasPrefix("GET%26"))")
print("Contains https%3A%2F%2Fplatform.fatsecret.com%2Frest%2Fserver.api: \(baseString.contains("https%3A%2F%2Fplatform.fatsecret.com%2Frest%2Fserver.api"))")
print("Contains method%3Dfoods.search: \(baseString.contains("method%3Dfoods.search"))")
