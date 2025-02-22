import 'package:flutter/material.dart';
import 'package:patico/widget/button.dart';
import 'package:patico/screens/home_screen.dart';
import 'package:patico/services/authentication.dart';
import 'package:patico/widget/snackbar.dart';
import 'package:patico/widget/text_field.dart';

import 'package:patico/screens/login.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();  // Yeni controller

  bool isLoading = false;

  @override
  void dispose() {
    super.dispose();
    emailController.dispose();
    passwordController.dispose();
   nameController.dispose();
    confirmPasswordController.dispose();
  }

  void signupUser() async {
    // set is loading to true.
    setState(() {
      isLoading = true;
    });
    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        isLoading = false;
      });
      showSnackBar(context, "Passwords do not match.");
      return;
    }
    // signup user using our authmethod
    String res = await AuthMethod().signupUser(
        email: emailController.text,
        password: passwordController.text,
        name: nameController.text,
      phone: phoneController.text,);
    // if string return is success, user has been creaded and navigate to next screen other withse show error.
    if (res == "success") {
      setState(() {
        isLoading = false;
      });
      //navigate to the next screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } else {
      setState(() {
        isLoading = false;
      });
      // show error
      showSnackBar(context, res);
    }
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: SingleChildScrollView(  // Add this to allow scrolling
          child: SizedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: height / 2.8,
                  child: Image.asset('images/signup.jpg'),
                ),
                TextFieldInput(
                    icon: Icons.person,
                    textEditingController: nameController,
                    hintText: 'Enter your name',
                    textInputType: TextInputType.text),
                TextFieldInput(
                    icon: Icons.email,
                    textEditingController: emailController,
                    hintText: 'Enter your email',
                    textInputType: TextInputType.text),
                TextFieldInput(
                    icon: Icons.phone,
                    textEditingController: phoneController,
                    hintText: 'Enter your phone number',
                    textInputType: TextInputType.text),
                TextFieldInput(
                  icon: Icons.lock,
                  textEditingController: passwordController,
                  hintText: 'Enter your password',
                  textInputType: TextInputType.text,
                  isPass: true,
                ),
                  TextFieldInput(
                    icon: Icons.lock,
                    textEditingController: confirmPasswordController,  // Yeni şifre doğrulama alanı
                    hintText: 'Confirm your password',
                    textInputType: TextInputType.text,
                    isPass: true,
                ),
                MyButtons(onTap: signupUser, text: "Sign Up"),
                const SizedBox(height: 50),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        " Login",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
