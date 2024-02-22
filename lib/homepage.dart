import 'package:flutter/material.dart';
import 'package:write4me/API/api.dart';
import 'package:write4me/components/button_box.dart';
import 'package:write4me/components/dropdown.dart';
import 'package:write4me/components/option_chips.dart';
import 'package:write4me/components/static.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final api = API();

  final TextEditingController _controller = TextEditingController();
  String _response = '';
  bool _isLoading = false;
  String selectedSource = 'Source 1'; 

  final List<String> _sources = [
    'Source 1', 
    'Source 2', 
    'Source 3'
  ];

  void _submitTopic() async {
    
    setState(() {
      _isLoading = true;
    });

    String response = '';

    if (selectedSource == 'Source 1') {
      response = await api.fetchResponse1(_controller.text);
    } else if (selectedSource == 'Source 2') {
      response = await api.fetchResponse2(_controller.text, "openchat/openchat-7b");
    } else if (selectedSource == 'Source 3') {
      response = await api.fetchResponse2(
        _controller.text, 
        "mistralai/mistral-7b-instruct:free"
      );
    }

    setState(() {
      _response = response;
      _isLoading = false; 
    });

  }

  void _selectExample(String example) {
    setState(() {
      _controller.text = example;
    });
  }

  @override
  Widget build(BuildContext context) {
    ScreenSize.init(context);
    return Scaffold(
      appBar: AppBar(
      title: const Text('Start Writing'),
      centerTitle: true,
    ),
      body: _buildBody(),
    );
  }

 

  Widget _buildBody( ) {
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(),
             SizedBox(height: ScreenSize.height * 0.1,),
            _buildTopicSection(),
            
            _buildExamplesSection(), 
            _buildSubmitButton(),
                     SizedBox(
          height: ScreenSize.height * 0.01,
        ),

            if (_isLoading)
              const CircularProgressIndicator()
            else
              Container(),
            if (!_isLoading && _response.isNotEmpty)
              ResponseBox(response: _response),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Image.asset(
      'assests/images/playstore.png', 
      width: ScreenSize.width * 0.4, 
      height: ScreenSize.height * 0.25, 
      fit: BoxFit.cover,
    );
  }

  Widget _buildTopicSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Topic',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold
              ),
            ),
            _buildSourceDropdown()  
          ],
        ),
         SizedBox(height: ScreenSize.height * 0.03),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'Enter text',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
          ),
          keyboardType: TextInputType.multiline,
          maxLines: 3, 
        ),
      ],
    );
  }

  Widget _buildSourceDropdown() {
    return SourceDropdown(
      selectedSource: selectedSource,
      onChanged: (newValue) {
        setState(() {
          selectedSource = newValue!;
        });
      },
      sources: _sources,
    );
  }

  Widget _buildExamplesSection() {
    return Column(
      children: [
        SizedBox(height: ScreenSize.height * 0.03),
        OptionChips(onSelectExample: _selectExample),
         SizedBox(height: ScreenSize.height * 0.03),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitTopic,
      child: const Text('Go'),
    );
  }

}