import 'package:flutter/material.dart';
import 'package:patico/widget/button.dart';
import 'package:patico/services/google_auth.dart';
import 'package:patico/screens/forgot_password.dart';
import 'package:patico/screens/phone_login.dart';
import 'package:patico/screens/home_screen.dart';
import 'package:patico/services/authentication.dart';
import 'package:patico/widget/snackbar.dart';
import 'package:patico/widget/text_field.dart';
import 'signup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    super.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  // email and password auth part
  void loginUser() async {
    setState(() {
      isLoading = true;
    });
    // login user using our authmethod
    String res = await AuthMethod().loginUser(
        email: emailController.text, password: passwordController.text);

    if (res == "success") {
      setState(() {
        isLoading = false;
      });
      // navigate to the home screen
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
      // resizeToAvoidBottomInset: false,
      backgroundColor: Colors.pink[100],
      body: SafeArea(
        child: SingleChildScrollView( // Bu satırı ekleyin
          child: SizedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: height / 2.7,
                  child: Image.asset('images/login.jpg'),
                ),
                TextFieldInput(
                    icon: Icons.person,
                    textEditingController: emailController,
                    hintText: 'Enter your email',
                    textInputType: TextInputType.text),
                TextFieldInput(
                  icon: Icons.lock,
                  textEditingController: passwordController,
                  hintText: 'Enter your password',
                  textInputType: TextInputType.text,
                  isPass: true,
                ),
                const ForgotPassword(),
                MyButtons(onTap: loginUser, text: "Log In"),

                Row(
                  children: [
                    Expanded(
                      child: Container(height: 1, color: Colors.black26),
                    ),
                    const Text("  or  "),
                    Expanded(
                      child: Container(height: 1, color: Colors.black26),
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    onPressed: () async {
                      await FirebaseServices().signInWithGoogle();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomePage(),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Image.network(
                            "https://ouch-cdn2.icons8.com/VGHyfDgzIiyEwg3RIll1nYupfj653vnEPRLr0AeoJ8g/rs:fit:456:456/czM6Ly9pY29uczgu/b3VjaC1wcm9kLmFz/c2V0cy9wbmcvODg2/LzRjNzU2YThjLTQx/MjgtNGZlZS04MDNl/LTAwMTM0YzEwOTMy/Ny5wbmc.png",
                            height: 35,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Continue with Google",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const PhoneAuthentication(),
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "SignUp",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Container socialIcon(image) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFedf0f8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black45,
          width: 2,
        ),
      ),
      child: Image.network(
        image,
        height: 40,
      ),
    );
  }
}
