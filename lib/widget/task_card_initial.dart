import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TaskCardInitial extends StatelessWidget {
  const TaskCardInitial({super.key, required this.onCreateTask});

  final VoidCallback onCreateTask;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 173;
        final radius = BorderRadius.circular(26 * scale);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8.97,
                offset: Offset(0, 3.66),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned(
                  left: (-13 + (106.825 - 82.799) / 2) * scale,
                  top: (99 + (127.889 - 111.46) / 2) * scale,
                  width: 82.8 * scale,
                  height: 111.46 * scale,
                  child: Transform.rotate(
                    angle: -0.238935,
                    child: SvgPicture.asset('assets/tasks/home_paper.svg'),
                  ),
                ),
                Positioned(
                  left: 67 * scale,
                  top: 106 * scale,
                  width: 118 * scale,
                  height: 173 * scale,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: -9.61 * scale,
                          top: -15.79 * scale,
                          width: 137.21 * scale,
                          height: 206.03 * scale,
                          child: Image.asset(
                            'assets/tasks/empty_frog.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16 * scale,
                  right: 16 * scale,
                  top: 24 * scale,
                  height: 52 * scale,
                  child: Material(
                    color: Colors.white,
                    borderRadius: radius,
                    child: InkWell(
                      borderRadius: radius,
                      onTap: onCreateTask,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Создать задачу',
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF777777),
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12 * scale,
                                  height: 14 / 12,
                                ),
                              ),
                            ),
                            SizedBox(width: 4 * scale),
                            SvgPicture.asset(
                              'assets/tasks/plus.svg',
                              width: 32 * scale,
                              height: 32 * scale,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
