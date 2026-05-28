import 'package:hand_camera/generated/l10n.dart';
import 'package:hand_camera/providers/rewarder_model.dart';
import 'package:hand_camera/providers/udider_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:watermark_widget/watermark_widget.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  @override
  void initState() {
    super.initState();
    final rewarderModel = Provider.of<RewarderModel>(context, listen: false);
    rewarderModel.queryData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Operation Log', style: TextStyle(fontSize: 18)),
        centerTitle: true,
      ),
      body: Container(
        padding: .all(12),
        width: double.infinity,
        child: WatermarkWidget(
          text: S.current.app_name,
          opacity: 0.2,
          color: Theme.of(context).colorScheme.inversePrimary,
          rotationAngle: -0.5,
          fontSize: 24,
          horizontalInterval: 120,
          verticalInterval: 120,
          child: Column(
            children: [
              SizedBox(
                child: Consumer<UdiderModel>(
                  builder: (context, udiderModel, child) {
                    return Text(
                      'UserId:${udiderModel.uuid}',
                      style: TextStyle(fontWeight: .bold, fontSize: 18),
                    );
                  },
                ),
              ),
              Container(
                margin: .only(top: 12),
                width: double.infinity,
                child: Consumer<RewarderModel>(
                  builder: (context, rewarderModel, child) {
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: rewarderModel.list.length,
                      itemBuilder: (BuildContext context, int index) {
                        return Text(
                          // ignore: prefer_interpolation_to_compose_strings
                          '${index + 1}、 ' +
                              rewarderModel.list[index]['record_time'],
                          style: TextStyle(fontSize: 18),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
