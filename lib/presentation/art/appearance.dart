import '../../domain/models/player.dart';
class CareerAppearance {
  static const asset='assets/images/careers/male_doll.png';
  static const baseJobs=['unemployed','student','part_timer','engineer','artist','warrior','scholar','president','mentor','hero'];
  static const extraJobs=['apprentice','adventurer','doctor','mage','ranger','merchant','archmage','paladin','ranger_master'];
  static const newJobs=['alchemist', 'bard', 'chef', 'guardian', 'dancer', 'beast_tamer', 'sage', 'maestro', 'gourmet_master', 'warlord', 'celestial_dancer', 'dragon_tamer'];
  static const jobs=[...baseJobs,...extraJobs,...newJobs];
  static bool isExtra(String id)=>extraJobs.contains(id);
  static int columns(String id)=>isExtra(id)?3:5;
  static int rows(String id)=>isExtra(id)?6:4;
  static String assetFor(CharacterGender gender,{String jobId='unemployed'}) =>
    'assets/images/careers/${gender.name}${isExtra(jobId)?"_extra":""}_doll.png';
  static int? index(String id){
    final list=isExtra(id)?extraJobs:baseJobs;
    final i=list.indexOf(id), cols=columns(id);
    return i<0?null:(i~/cols)*cols*2+i%cols;
  }
}
