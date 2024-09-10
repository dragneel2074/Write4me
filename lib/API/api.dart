// import 'dart:convert';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:write4me/API/api_endpoints.dart';
// import 'package:write4me/API/requests.dart';
// import 'package:http/http.dart' as http;
// import 'package:write4me/API/response.dart';

// class API {

// final model = GenerativeModel(
//       model: 'gemini-pro', apiKey: dotenv.env['GEM_API_KEY'] ?? '');
      
// Future<String> fetchResponse1(String topic) async {
//     try {
//       // Initialize Gemini
//       final prompt =
//           "The aim is to provide essays, stories, and jokes. If user asks for other things. Just output: I only help with Essays, Stories and Jokes. Understand user needs for tone, length, format. If lenght is not given, maximum limit is 200 words. Expand creatively while staying on topic. Write and deliver sequentially. Ensure quality and engagement. Default to markdown. Solve problems to meet content needs. Don't write unrequired text. Only write what user asks. User: $topic";
//       final content = [Content.text(prompt)];
      
//       final response = await model.generateContent(content);
//       return '${response.text}';
//     } catch (e) {
//       // Handle any errors that occur during the Gemini API call
//       return 'Something went Wrong! Try again later'; // Return an empty string in case of error
//     }
//   }

//   Future<String> fetchResponse2(String topic, String model) async {
//     final prompt =
//         "The aim is to provide essays, stories, and jokes. If user asks for other things. Just output: I only help with Essays, Stories and Jokes. Understand user needs for tone, length, format. If length is not given, maximum limit is 200 words. Expand creatively while staying on topic. Write and deliver sequentially. Ensure quality and engagement. Default to markdown. Solve problems to meet content needs. Don't write unrequired text. Only write what user asks. User: $topic";

//     // Create a ChatRequest object
//     final chatRequest = ChatRequest(
//       model: model,
//       maxTokens: 300,
//       temperature: 0.7,
//       messages: [ChatMessage(role: "user", content: prompt)],
//     );

//     try {
//       // Assuming you have the completionsEndpoint and headers defined elsewhere
//       var response = await http.post(
//         completionsEndpoint, // Make sure to parse the endpoint URI
//         headers: headers,
//         body: json.encode(chatRequest.toJson()),
//       );

//       if (response.statusCode == 200) {
//         // Parse the response body into the ChatResponse model
//         final chatResponse = ChatResponse.fromJson(json.decode(response.body));

//         // Assuming the structure of the response allows directly accessing the first choice's content
//         if (chatResponse.choices.isNotEmpty) {
//           return chatResponse.choices.first.message.content;
//         } else {
//           return 'No completion found.';
//         }
//       } else {
//         return 'Something went wrong. Status code: ${response.statusCode}';
//       }
//     } catch (e) {
//       return "Error: Failed to fetch response";
//     }
//   }
// }