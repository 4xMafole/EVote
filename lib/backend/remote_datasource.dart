import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:e_vote/backend/errors.dart';
import 'package:e_vote/models/candidate_model.dart';
import 'package:e_vote/models/voter_model.dart';

class ElectionDataSource {
  /**
   * TESTING BLOCKCHAIN
   *  - change baseUrl
   *  - change owner(genesis)
   */
  BaseOptions customOptions = BaseOptions(
    baseUrl:
        "https://u1uzlkzvx3-u1dpmik1xz-connect.us1-azure.kaleido.io/instances/0xf0cf7de449e93b94376f85ea2ac464fadabe8a4d/",
    headers: {
      "authorization":
          "Basic dTFrd2M5Njk4OTpVZDBIOTR4Uno3YmhxaDZaM3FZdjg2M1ZzX192V0ZkSG9jM0RfMlh5dFY0",
    },
    contentType: Headers.jsonContentType,
  );
  Dio dioClient = Dio();

  // API KEY - u0z6a32mf8-WeS3ikcXhfPWu4P/B9Llw5j3wB1iCEyBppUJS5r83n0=
  var httpClient = HttpClient();
  String adminAddress = "0xe120bbbf654a3bb983805cd7b5c565bb4b7de344";
  String ownerAddress = "0x35f59a3ec9d08d5e78f1afce21cd87dfb4f65eb5";

  //!Fetches the address of the admin from the blockchain
  Future<String> getAdmin() async {
    dioClient.options = customOptions;
    var response = await dioClient.get("admin?kld-from=$adminAddress");
    return response.data["output"];
  }

  //!Fetches the count of registered candidates in the election
  Future<int> getCandidateCount() async {
    dioClient.options = customOptions;

    var response = await dioClient.get(
      "candidate_count",
      queryParameters: {"kld-from=": adminAddress},
    );
    print("getCandidateCount... ${response.data["output"].toString()}");
    return int.parse(response.data["output"]);
  }

  //!Fetches the count of regsitered voters in the elction
  Future<int> getVoterCount() async {
    dioClient.options = customOptions;
    var response = await dioClient.get(
      "voter_count",
      queryParameters: {"kld-from=": adminAddress},
    );
    print("getVoterCount... ${response.data["output"].toString()}");
    return int.parse(response.data["output"]);
  }

  //!Fetches the current state of the election - CREATED, ONGOING or STOPPED
  Future<String> getElectionState() async {
    dioClient.options = customOptions;
    var response = await dioClient.get(
      "checkState",
      queryParameters: {"kld-from=": adminAddress},
    );
    print("getElectionState... ${response.data["state"].toString()}");
    return response.data["state"];
  }

  //!Fetches a short description of the election
  Future<String> getDescription() async {
    dioClient.options = customOptions;
    var response = await dioClient.get(
      "description",
      queryParameters: {"kld-from=": adminAddress},
    );
    print("getDescription... ${response.data["output"].toString()}");
    return response.data["output"];
  }

  //!Fetches the details of a candidate - ID, Name, Proposal
  Future<Candidate> getCandidate(int id) async {
    dioClient.options = customOptions;
    var response =
        await dioClient.get("displayCandidate?_ID=$id&kld-from=$adminAddress");
    return Candidate.fromJson(response.data);
  }

  //!Fetches the details of all the registered candidates
  Future<List<Candidate>> getAllCandidates() async {
    dioClient.options = customOptions;
    int count = await getCandidateCount();
    var list = List<int>.generate(count, (index) => index + 1);
    List<Candidate> result = [];

    await Future.wait(list.map((e) async {
      var response = await dioClient
          .get(
            "displayCandidate?_ID=$e&kld-from=$adminAddress",
          )
          .catchError((error) => print("displayCandidate $error"));
      print("getAllCandidates... ${response}");

      result.add(Candidate.fromJson(response.data));
    }));

    return result;
  }

  //!Fetches the details of a voter - ID, Address, DelegateAddress and Weight
  Future<Voter> getVoter(int id, String owner) async {
    dioClient.options = customOptions;
    var response = await dioClient
        .get("getVoter?ID=$id&owner=$owner&kld-from=$adminAddress");
    return Voter.fromJson(response.data);
  }

  //!Fetches the details of all voters
  Future<List<Voter>> getAllVoters() async {
    dioClient.options = customOptions;
    int count = await getVoterCount();
    var list = List<int>.generate(count, (index) => index + 1);
    List<Voter> result = [];
    await Future.wait(list.map((e) async {
      var response = await dioClient
          .get(
            "getVoter?ID=$e&owner=$ownerAddress&kld-from=$adminAddress",
          )
          .catchError((error) => print("displayCandidate $error"));
      print("getAllVoters... ${response}");

      result.add(Voter.fromJson(response.data));
    }));

    print(result.length);
    return result;
  }

  //!Fetches the result of the candidate
  Future<Either<ErrorMessage, Candidate>> showCandidateResult(int id) async {
    dioClient.options = customOptions;
    try {
      var response =
          await dioClient.get("showResults?_ID=$id&kld-from=$adminAddress");
      return Right(Candidate.result(response.data));
    } catch (e) {
      return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Fetches the results of all the candidates
  Future<Either<ErrorMessage, List<Candidate>>> showResults() async {
    dioClient.options = customOptions;
    int count = await getCandidateCount();
    if (await getElectionState() != "CONCLUDED") {
      return Left(ErrorMessage(message: "The election has not concluded yet."));
    }
    var list = List<int>.generate(count, (index) => index + 1);
    List<Candidate> result = [];

    await Future.wait(list.map((e) async {
      var response = await dioClient
          .get(
            "showResults?_ID=$e&kld-from=$adminAddress",
          )
          .catchError((error) => print("displayCandidate $error"));
      print("showResults... ${response}");

      result.add(Candidate.result(response.data));
    }));

    return Right(result);
  }

  //!Returns the winner of the election
  Future<Either<ErrorMessage, Candidate>> getWinner() async {
    dioClient.options = customOptions;
    try {
      var response = await dioClient.get("showWinner?kld-from=$adminAddress");
      return Right(Candidate.winner(response.data));
    } catch (e) {
      return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to register a new candidate
  Future<Either<ErrorMessage, String>> addCandidate(
      String name, String proposal) async {
    dioClient.options = customOptions;
    Map<String, dynamic> map = {
      "_name": name,
      "_proposal": proposal,
      "owner": ownerAddress
    };
    try {
      var response = await dioClient.post(
        "addCandidate?kld-from=$adminAddress&kld-sync=true",
        data: map,
      );
      print("addCandidate... ${response.data["transactionHash"]}");

      return Right(response.data["transactionHash"]);
    } catch (e) {
      print(e.response.data["error"]);
      return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to register a new voter
  Future<Either<ErrorMessage, String>> addVoter(String voter) async {
    dioClient.options = customOptions;
    Map<String, dynamic> map = {"_voter": voter, "owner": ownerAddress};
    try {
      var response = await dioClient.post(
        "addVoter?kld-from=$adminAddress&kld-sync=true",
        data: map,
      );
      print("addVoter...${response.data["transactionHash"]}");
      return Right(response.data["transactionHash"]);
    } catch (e) {
      if (e.response.data["error"] == "DataEncodingError")
        return Left(
            ErrorMessage(message: "Invalid arguments. Please try again."));
      else if (voter == adminAddress)
        return Left(ErrorMessage(message: e.response.data["error"]));
      else
        return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to delegate your vote to someone else
  Future<Either<ErrorMessage, String>> delegateVoter(
      String delegate, String owner) async {
    dioClient.options = customOptions;
    print(delegate + "   " + owner);
    Map<String, dynamic> map = {"_delegate": delegate, "owner": owner};
    try {
      var response = await dioClient.post(
        "delegateVote?kld-from=$adminAddress&kld-sync=true",
        data: map,
      );
      print("delegateVoter...${response.data["transactionHash"]}");
      return Right(response.data["transactionHash"]);
    } catch (e) {
      if (e.response.data["error"] == "DataEncodingError")
        return Left(
            ErrorMessage(message: "Invalid arguments. Please try again."));
      else
        return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to end election
  Future<Either<ErrorMessage, String>> endElection() async {
    dioClient.options = customOptions;
    Map<String, dynamic> map = {"owner": ownerAddress};
    try {
      var response = await dioClient.post(
        "endElection?kld-from=$adminAddress&kld-sync=true",
        data: map,
      );
      print("endElection...${response.data["transactionHash"]}");
      return Right(response.data["transactionHash"]);
    } catch (e) {
      return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to start election
  Future<Either<ErrorMessage, String>> startElection() async {
    dioClient.options = customOptions;
    Map<String, dynamic> map = {"owner": ownerAddress};
    try {
      var response = await dioClient.post(
        "startElection?kld-from=$adminAddress&kld-sync=true",
        data: map,
      );
      return Right(response.data["transactionHash"]);
    } catch (e) {
      print(e.response.data["error"]);
      return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to perform vote
  Future<Either<ErrorMessage, String>> vote(int id, String owner) async {
    dioClient.options = customOptions;
    Map<String, dynamic> map = {"owner": owner, "_ID": id};
    try {
      var response = await dioClient.post(
        "vote?kld-from=$adminAddress&kld-sync=true",
        data: map,
      );
      print("vote... $response");
      return Right(response.data["transactionHash"]);
    } catch (e) {
      if (e.response.data["error"] == "DataEncodingError")
        return Left(
            ErrorMessage(message: "Invalid arguments. Please try again."));
      else
        return Left(ErrorMessage(message: e.response.data["error"]));
    }
  }

  //!Function to get voter's profile
  Future<Voter> getVoterProfile(String address) async {
    dioClient.options = customOptions;
    var response = await dioClient
        .get("voterProfile?voterAddress=$address&kld-from=$adminAddress");
    return Voter.profileJson(response.data, address);
  }
}
